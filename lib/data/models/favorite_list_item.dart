import 'favorite_response_dto.dart';
import 'tmdb_movie_dto.dart';

/// 내 즐겨찾기 카드 한 장의 데이터. MovieLog 즐겨찾기 + TMDB 영화 정보를 movieId로 합친 것이다.
///
/// TMDB 조회에 실패한 카드는 [movie]가 null이고 [errorMessage]가 있다.
/// 그 카드만 placeholder로 보여 주고, 다른 카드는 그대로 둔다.
class FavoriteListItem {
  const FavoriteListItem({
    required this.favorite,
    this.movie,
    this.errorMessage,
    this.isRetrying = false,
  });

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
  final String? errorMessage;

  /// 이 카드의 영화 정보만 다시 조회하는 중.
  final bool isRetrying;

  bool get hasMovie => movie != null;

  FavoriteListItem copyWith({
    TmdbMovieDto? movie,
    String? errorMessage,
    bool clearError = false,
    bool? isRetrying,
  }) => FavoriteListItem(
    favorite: favorite,
    movie: movie ?? this.movie,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    isRetrying: isRetrying ?? this.isRetrying,
  );
}
