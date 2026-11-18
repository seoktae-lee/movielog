/// 즐겨찾기 한 건. (`POST /v8/favorites` result, `GET /v8/favorites` 배열의 항목)
///
/// 제목·포스터는 없다. TMDB 영화 id(`movieId`)만 있고, 화면 카드는 이 id로 TMDB를 조회해 만든다.
class FavoriteResponseDto {
  const FavoriteResponseDto({
    required this.favoriteId,
    required this.movieId,
    required this.createdAt,
  });

  factory FavoriteResponseDto.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('FavoriteResponseDto must be a JSON object.');
    }
    return FavoriteResponseDto(
      favoriteId: (json['favoriteId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int favoriteId;
  final int movieId;
  final DateTime createdAt;
}
