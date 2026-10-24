import 'tmdb_movie_dto.dart';

/// Popular·Discover처럼 페이지 단위로 오는 응답.
///
/// 영화 배열(`results`)과 함께 `page`·`total_pages` 같은 metadata가 오므로
/// 한 객체로 묶어야 "다음 페이지를 더 요청할지"를 판단할 수 있다.
class TmdbMoviePageDto {
  const TmdbMoviePageDto({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  final int page;
  final List<TmdbMovieDto> results;

  /// 마지막 페이지 판단에 쓴다.
  final int totalPages;

  /// 전체 탐색 결과 개수. 이만큼 모두 내려받는다는 뜻이 아니다.
  final int totalResults;

  factory TmdbMoviePageDto.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? const [];

    return TmdbMoviePageDto(
      page: (json['page'] as num? ?? 1).toInt(),
      results: rawResults
          .map((item) => TmdbMovieDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalPages: (json['total_pages'] as num? ?? 0).toInt(),
      totalResults: (json['total_results'] as num? ?? 0).toInt(),
    );
  }
}
