import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면 전용 ViewModel. 조회(6주차) + 수정·삭제·다중 삭제(7주차).
///
/// 1) 자체 백엔드에서 평점 목록을 받고
/// 2) 각 평점의 movieId로 TMDB 영화 정보를 붙인다.
///
/// [memberId]는 회원가입 결과로 저장한 학습용 ID(LearningMemberSession)다. 인증이 아니다.
///
/// 쓰기 성공과 목록 재조회 성공은 다른 상태다.
/// 쓰기가 성공하면 GET이 실패해도 저장 실패로 되돌리지 않고 [refreshWarning]만 남긴다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;

  /// movieId → 영화. 같은 영화는 한 번만 조회한다.
  /// TMDB에 없는 영화(404)는 null로 캐시해 다시 묻지 않는다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;

  /// Error면 실패 문구, Success면 "일부 영화 정보를 못 가져왔다"는 안내.
  String? message;

  /// 쓰기는 성공했는데 그 뒤 GET만 실패했을 때의 안내. "조회만" 다시 시도하게 한다.
  String? refreshWarning;

  /// 다중 삭제 일부 실패처럼 화면이 Snackbar로 한 번 보여 줄 문구.
  String? snackbarMessage;

  // ── 다중 선택 (Challenge) ──
  bool isEditMode = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_disposed || version != _requestVersion) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      // 같은 movieId는 캐시를 쓰고, 영화 조회 실패가 평점 목록을 지우지 않는다.
      for (final rating in rawRatings) {
        if (_disposed || version != _requestVersion) return;
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] = await _movieService.findMovieById(
              rating.movieId,
            );
          } on DioException {
            // 일시적 네트워크 실패는 캐시하지 않는다. 다음 로딩에서 다시 시도한다.
          }
        }
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }
      if (_disposed || version != _requestVersion) return;

      ratings = entries;
      refreshWarning = null;
      // 지워졌거나 남의 것으로 확인된 평점은 선택 목록에서도 뺀다.
      selectedRatingIds.retainAll(entries.map((e) => e.rating.ratingId));
      // 빈 배열은 실패가 아니라 Empty다.
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } on DioException catch (error) {
      if (_disposed || version != _requestVersion) return;
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    }
    if (!_disposed && version == _requestVersion) notifyListeners();
  }

  /// 쓰기 성공 뒤 목록을 다시 읽는다. GET 실패는 저장 실패로 다시 던지지 않는다.
  Future<void> _refreshAfterWrite() async {
    await load(); // load()는 GET 실패를 status=error로 기록한다.
    if (_disposed) return;
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  /// 평점 수정. score는 항상, comment는 Dialog에 남아 있는 값을 그대로 보낸다.
  /// (빈 칸이면 null → 후기 삭제. 기존 후기를 유지하려면 Dialog에 기존 값이 채워져 있다)
  ///
  /// 쓰기 실패만 rethrow해서 Dialog가 실패로 처리한다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
    } on DioException catch (error) {
      // 403(남의 평점)·404(이미 없는 평점)는 화면 목록이 서버와 어긋났다는 뜻 → 다시 조회
      if (shouldRefreshAfterRatingError(error)) await load();
      rethrow;
    }
    await _refreshAfterWrite();
  }

  /// 평점 단건 삭제. 성공(204)하면 곧바로 목록을 다시 읽는다.
  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      if (shouldRefreshAfterRatingError(error)) await load();
      rethrow;
    }
    await _refreshAfterWrite();
  }

  // ── 다중 선택 (Challenge) ──

  void enterEditMode() {
    isEditMode = true;
    selectedRatingIds.clear();
    notifyListeners();
  }

  /// "취소": 선택을 해제하고 기본 목록으로 돌아간다.
  void exitEditMode() {
    isEditMode = false;
    selectedRatingIds.clear();
    notifyListeners();
  }

  void toggleSelected(int ratingId) {
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    notifyListeners();
  }

  /// 선택한 평점을 하나씩 삭제한다. 확인 Dialog가 닫힌 **뒤** 화면에서 호출한다.
  ///
  /// 실패한 ratingId는 선택 상태로 남겨 다시 시도할 수 있게 하고, 성공한 것만 지운다.
  /// 원본 Set을 순회하면서 remove하면 ConcurrentModificationError가 나므로 toList()로 복사해 돈다.
  Future<void> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return;
    isDeletingSelected = true;
    notifyListeners();
    var failed = 0;
    try {
      for (final ratingId in selectedRatingIds.toList()) {
        try {
          await _service.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException {
          failed++; // 실패한 항목은 선택 상태를 유지한다.
        }
      }
    } finally {
      isDeletingSelected = false;
      // 예상하지 못한 오류에도 로딩 오버레이를 반드시 해제한다.
      if (!_disposed) notifyListeners();
    }
    if (_disposed) return;
    await _refreshAfterWrite(); // GET 실패는 삭제 성공 여부와 분리한다.
    if (_disposed) return;
    if (failed > 0) {
      snackbarMessage = '$failed개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.';
    } else {
      isEditMode = false;
    }
    notifyListeners();
  }

  String? takeSnackbarMessage() {
    final value = snackbarMessage;
    snackbarMessage = null;
    return value;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
