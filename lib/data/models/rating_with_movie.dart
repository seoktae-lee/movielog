import 'rating_dto.dart';
import 'tmdb_movie_dto.dart';

/// 평점 한 건 + 그 영화의 TMDB 정보.
///
/// 평점은 자체 백엔드가 진짜 주인이다. TMDB에서 영화를 못 찾아도
/// 평점은 버리지 않고 [movie]만 null로 둔다. (화면은 placeholder를 그린다)
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;

  /// TMDB에서 찾지 못했거나 가져오지 못했으면 null.
  final TmdbMovieDto? movie;
}
