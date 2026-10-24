import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_with_movie.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

/// "내가 등록한 평점" 화면이 조회할 회원.
///
/// 인증된 '내 계정'이 아니라 학습용 공개 데이터(memberId 1)다.
/// 실제 회원 식별은 JWT 주차에서 바뀐다. 화면에 입력창을 두지 않고 상수로 관리한다.
///
/// 디버그 캡처용으로만 `--dart-define=SAMPLE_MEMBER_ID=3`처럼 바꿀 수 있다.
/// (3 = 평점 없는 회원 → Empty, 4 = 없는 회원 → 404 Error)
const int sampleMemberId = int.fromEnvironment(
  'SAMPLE_MEMBER_ID',
  defaultValue: 1,
);

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// "내가 등록한 평점" 화면 전용 ViewModel.
///
/// 1) 자체 백엔드에서 평점 목록을 받고
/// 2) 각 평점의 movieId로 TMDB 영화 정보를 붙인다.
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

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
