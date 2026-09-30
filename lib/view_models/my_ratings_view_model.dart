import 'package:flutter/foundation.dart';

import '../data/models/member_rating_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/movielog_member_service.dart';
import '../data/services/tmdb_movie_service.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// 내 평점 한 건 + 그 영화의 TMDB 정보.
class MyRatingItem {
  const MyRatingItem({required this.rating, this.movie});

  final MemberRatingDto rating;

  /// TMDB에서 못 가져오면 null. 그래도 평점은 보여 준다.
  final TmdbMovieDto? movie;
}

/// 마이페이지의 "내가 남긴 평점" 영역 전용 ViewModel.
///
/// 1) MovieLog 자체 API에서 평점을 받고
/// 2) 각 평점의 `movieId`로 TMDB 상세를 불러 제목·포스터를 붙인다.
/// 우리 DB에는 영화 정보가 없고 TMDB id만 있기 때문이다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._memberService,
    this._tmdbService, {
    required this.memberId,
  });

  final MovieLogMemberService _memberService;
  final TmdbMovieService _tmdbService;
  final int memberId;

  List<MyRatingItem> items = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  bool _disposed = false;

  Future<void> load() async {
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final ratings = await _memberService.fetchMemberRatings(memberId);

      // 영화 정보는 서로 기다릴 필요가 없어 동시에 요청한다.
      // 한 편이 실패해도 나머지는 보여 주도록 각각 실패를 null로 바꾼다.
      final movies = await Future.wait(ratings.map(_fetchMovieOrNull));

      items = [
        for (var i = 0; i < ratings.length; i++)
          MyRatingItem(rating: ratings[i], movie: movies[i]),
      ];
      status = items.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
    } on MovieLogApiException catch (error) {
      status = MyRatingsLoadStatus.error;
      message = error.message;
    }

    if (!_disposed) notifyListeners();
  }

  Future<TmdbMovieDto?> _fetchMovieOrNull(MemberRatingDto rating) async {
    try {
      return await _tmdbService.fetchMovieDetail(rating.movieId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
