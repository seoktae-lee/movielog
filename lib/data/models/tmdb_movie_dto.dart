/// TMDB 영화 한 편의 응답을 담는 DTO.
///
/// Popular·Discover의 `results` 항목과 상세(`/movie/{id}`) 응답을 함께 표현한다.
/// 값만 담고, 화면에 어떻게 그릴지(연도 표시·placeholder 등)는 Widget이 정한다.
class TmdbMovieDto {
  const TmdbMovieDto({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
    required this.genreIds,
    required this.voteAverage,
    required this.popularity,
  });

  /// TMDB가 영화를 식별하는 값. 목록 index가 아니라 이 값을 평점의 `movieId`로 쓴다.
  final int id;
  final String title;

  /// 번역된 줄거리가 없으면 빈 문자열이 온다.
  final String overview;

  /// `/abc.jpg`처럼 파일 경로만 온다. 이미지 base URL과 size는 Widget이 붙인다.
  final String? posterPath;
  final String? backdropPath;

  /// `2025-07-01` 형식. 미개봉·정보 없음이면 null이거나 빈 문자열이다.
  final String? releaseDate;
  final List<int> genreIds;

  /// 10점 만점 평균 평점.
  final double voteAverage;
  final double popularity;

  factory TmdbMovieDto.fromJson(Map<String, dynamic> json) {
    return TmdbMovieDto(
      // JSON 숫자는 int·double 어느 쪽으로도 올 수 있어 num으로 받고 변환한다.
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '제목 없음',
      overview: json['overview'] as String? ?? '',
      // snake_case(JSON) ↔ lowerCamelCase(Dart) 이름이 다르므로 Key를 직접 연결한다.
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String?,
      genreIds: _parseGenreIds(json),
      voteAverage: (json['vote_average'] as num? ?? 0).toDouble(),
      popularity: (json['popularity'] as num? ?? 0).toDouble(),
    );
  }

  /// 목록 응답은 `genre_ids: [28]`, 상세 응답은 `genres: [{id: 28, name: 액션}]`로 온다.
  static List<int> _parseGenreIds(Map<String, dynamic> json) {
    final ids = json['genre_ids'] as List<dynamic>?;
    if (ids != null) {
      return ids.map((value) => (value as num).toInt()).toList();
    }

    final genres = json['genres'] as List<dynamic>? ?? const [];
    return genres
        .map((item) => ((item as Map<String, dynamic>)['id'] as num).toInt())
        .toList();
  }
}
