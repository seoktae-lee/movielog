/// TMDB 공식 장르 하나. (`/genre/movie/list`)
///
/// 장르 이름을 앱에 하드코딩하고 ID만 따로 맞추지 않고, API가 준 id·name을 그대로 쓴다.
class TmdbGenreDto {
  const TmdbGenreDto({required this.id, required this.name});

  /// Discover의 `with_genres`에 넣는 값.
  final int id;
  final String name;

  factory TmdbGenreDto.fromJson(Map<String, dynamic> json) {
    return TmdbGenreDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}
