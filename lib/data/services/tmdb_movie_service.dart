import 'package:dio/dio.dart';

import '../models/tmdb_genre_dto.dart';
import '../models/tmdb_movie_dto.dart';
import '../models/tmdb_movie_page.dart';

/// TMDB 서버와 직접 통신하는 Service Layer.
///
/// HTTP 요청을 보내고 응답 JSON을 DTO로 바꾸는 일만 한다.
/// "인기 5개", "최대 30개", "지금 선택된 장르" 같은 화면 정책은 ViewModel이 정한다.
///
/// 요청 결과를 필드에 저장하지 않는다(stateless). 그래서 홈·목록·상세 ViewModel이
/// 이 인스턴스 하나를 함께 써도 서로의 결과가 섞이지 않는다.
class TmdbMovieService {
  TmdbMovieService(this._dio);

  final Dio _dio;

  /// 인기 영화 목록. (`GET /movie/popular`)
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/popular',
      queryParameters: {'language': 'ko-KR', 'page': page},
    );
    return TmdbMoviePageDto.fromJson(response.data ?? const {});
  }

  /// 조건으로 영화를 탐색한다. (`GET /discover/movie`)
  ///
  /// [genreIds]가 비었거나 null이면 `with_genres`를 아예 보내지 않는다(= 전체).
  /// 여러 개면 `|`(OR)로 이어 "이 중 하나라도 해당하는 영화"를 요청한다.
  /// (`,`로 이으면 AND라서 모든 장르를 동시에 가진 영화만 온다)
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/discover/movie',
      queryParameters: {
        'language': 'ko-KR',
        'page': page,
        'sort_by': 'popularity.desc',
        'include_adult': false,
        'include_video': false,
        if (genreIds != null && genreIds.isNotEmpty)
          'with_genres': genreIds.join('|'),
      },
    );
    return TmdbMoviePageDto.fromJson(response.data ?? const {});
  }

  /// 영화 공식 장르 목록. (`GET /genre/movie/list`)
  Future<List<TmdbGenreDto>> fetchGenres() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/genre/movie/list',
      queryParameters: {'language': 'ko'},
    );
    final genres = response.data?['genres'] as List<dynamic>? ?? const [];
    return genres
        .map((item) => TmdbGenreDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 영화 한 편의 상세 정보. (`GET /movie/{movie_id}`)
  ///
  /// 목록에서 상세로 갈 때는 이미 받은 DTO를 넘기므로 호출하지 않는다.
  /// URL로 상세에 바로 들어와 DTO가 없을 때만 `movieId`로 다시 조회한다.
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/$movieId',
      queryParameters: {'language': 'ko-KR'},
    );
    return TmdbMovieDto.fromJson(response.data ?? const {});
  }

  /// [fetchMovieDetail]과 같지만, TMDB에 없는 영화(404)면 예외 대신 null을 돌려준다.
  ///
  /// 404만 null로 바꾼다. 네트워크 오류 같은 다른 실패는 그대로 던져
  /// 호출한 쪽이 "없는 영화"와 "일시적 실패"를 구분할 수 있게 한다.
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    try {
      return await fetchMovieDetail(movieId);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
