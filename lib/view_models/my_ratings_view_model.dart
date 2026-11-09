import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty }

/// "내가 등록한 평점" 화면 전용 ViewModel.
///
/// 8주차: v7에는 토큰 기반 "내 평점 목록 GET"이 없다. 그래서 목록은 서버 조회가 아니라
/// **이번 세션에서 등록한 Rating**([SessionRatingStore])이고, 수정·삭제는 v7 보호 API로 보낸다.
///
/// - 평점의 movieId(TMDB id)로 TMDB 영화 정보를 붙이고, 못 찾으면 `영화 #{movieId}` placeholder.
/// - 수정 성공 result(Rating)로 그 카드만 바꾼다. 다시 GET하지 않는다.
/// - 401(AUTH401_2/3/4)은 세션 정리, 403·404·409는 안내만 하고 로그인 상태를 유지한다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._auth,
    this._store,
  ) {
    _store.addListener(_onStoreChanged);
  }

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;

  /// movieId → 영화. 같은 영화는 한 번만 조회한다. TMDB에 없는 영화(404)는 null로 캐시한다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _buildVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// "일부 영화 정보를 못 가져왔다" 같은 목록 위 안내.
  String? message;

  /// 다중 삭제 일부 실패처럼 화면이 Snackbar로 한 번 보여 줄 문구.
  String? snackbarMessage;

  // ── 다중 선택 (Challenge, 7주차) ──
  bool isEditMode = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  /// 처음 열 때: 로딩 표시 후 목록을 만든다.
  Future<void> load() => _rebuild(showLoading: true);

  /// 등록·수정·삭제로 보관함이 바뀌면 깜빡임 없이 다시 만든다. (영화 정보는 캐시에서)
  void _onStoreChanged() => _rebuild(showLoading: false);

  Future<void> _rebuild({required bool showLoading}) async {
    final version = ++_buildVersion;
    if (showLoading) {
      status = MyRatingsLoadStatus.loading;
      _notify();
    }

    final source = _store.ratings;
    final entries = <RatingWithMovie>[];
    var missingMovies = 0;
    for (final rating in source) {
      if (!_movieCache.containsKey(rating.movieId)) {
        try {
          _movieCache[rating.movieId] = await _movieService.findMovieById(
            rating.movieId,
          );
        } on DioException {
          // 일시적 실패는 캐시하지 않는다. 평점은 placeholder로 남긴다.
        }
        if (_disposed || version != _buildVersion) return;
      }
      final movie = _movieCache[rating.movieId];
      if (movie == null) missingMovies++;
      entries.add(RatingWithMovie(rating: rating, movie: movie));
    }
    if (_disposed || version != _buildVersion) return;

    ratings = entries;
    selectedRatingIds.retainAll(entries.map((e) => e.rating.ratingId));
    if (entries.isEmpty) isEditMode = false;
    status = entries.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    message = missingMovies > 0
        ? '일부 영화 정보를 가져오지 못해 "영화 #id"로 대신 표시합니다.'
        : null;
    _notify();
  }

  /// 평점 수정. score와 comment를 항상 함께 보낸다. (PATCH = 전체 교체)
  ///
  /// 실패는 rethrow해서 Dialog가 열린 채 문구를 보여 준다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final version = _auth.sessionVersion;
    try {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
      _store.replace(version, updated); // 다른 세션의 늦은 응답이면 store가 무시한다.
    } on DioException catch (error) {
      await _handleWriteError(error, version, ratingId);
      rethrow;
    }
  }

  /// 평점 단건 삭제. v7 성공은 200 + result null.
  Future<void> deleteRating(int ratingId) async {
    final version = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
      _store.remove(version, ratingId);
    } on DioException catch (error) {
      await _handleWriteError(error, version, ratingId);
      rethrow;
    }
  }

  /// 401은 세션 정리, 404는 이미 없는 평점이니 목록에서 뺀다. 403·409·네트워크는 안내만.
  Future<void> _handleWriteError(
    DioException error,
    int version,
    int ratingId,
  ) async {
    if (isSessionExpiredError(error)) {
      await _auth.expireSession(version);
    } else if (apiErrorCode(error) == 'RATING404_1') {
      _store.remove(version, ratingId);
    }
  }

  // ── 다중 선택 ──

  void enterEditMode() {
    isEditMode = true;
    selectedRatingIds.clear();
    _notify();
  }

  void exitEditMode() {
    isEditMode = false;
    selectedRatingIds.clear();
    _notify();
  }

  void toggleSelected(int ratingId) {
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    _notify();
  }

  /// 선택한 평점을 하나씩 삭제한다. 실패한 항목은 선택 상태로 남긴다.
  /// 세션이 만료되면 남은 요청을 보내지 않고 멈춘다. (같은 401을 여러 번 받지 않게)
  Future<void> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return;
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    _notify();
    var failed = 0;
    var expired = false;
    try {
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(ratingId);
          _store.remove(version, ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException catch (error) {
          if (isSessionExpiredError(error)) {
            expired = true;
            await _auth.expireSession(version);
            break;
          }
          if (apiErrorCode(error) == 'RATING404_1') {
            _store.remove(version, ratingId);
            selectedRatingIds.remove(ratingId);
            continue;
          }
          failed++;
        }
      }
    } finally {
      isDeletingSelected = false;
      _notify();
    }
    if (_disposed || expired) return;
    if (failed > 0) {
      snackbarMessage = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
    } else {
      isEditMode = false;
    }
    _notify();
  }

  String? takeSnackbarMessage() {
    final value = snackbarMessage;
    snackbarMessage = null;
    return value;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _buildVersion++;
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
