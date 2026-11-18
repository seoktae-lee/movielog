import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'tmdb_fixtures.dart';

/// Discover 요청 한 번의 조건.
typedef DiscoverCall = ({int page, List<int>? genreIds});

/// Search 요청 한 번의 조건.
typedef SearchCall = ({int page, String query});

/// 실제 서버 대신 fixture를 돌려주는 Service.
///
/// `implements`라서 Dio 없이 만들 수 있고, 어떤 요청이 들어왔는지 기록한다.
class FakeTmdbMovieService implements TmdbMovieService {
  FakeTmdbMovieService({
    Future<TmdbMoviePageDto> Function(int page)? onPopular,
    Future<TmdbMoviePageDto> Function(DiscoverCall call)? onDiscover,
    Future<List<TmdbGenreDto>> Function()? onGenres,
    Future<TmdbMovieDto> Function(int movieId)? onDetail,
    Future<TmdbMoviePageDto> Function(SearchCall call)? onSearch,
  }) : onPopular = onPopular ?? _defaultPopular,
       onDiscover = onDiscover ?? _defaultDiscover,
       onGenres = onGenres ?? _defaultGenres,
       onDetail = onDetail ?? _defaultDetail,
       onSearch = onSearch ?? _defaultSearch;

  Future<TmdbMoviePageDto> Function(int page) onPopular;
  Future<TmdbMoviePageDto> Function(DiscoverCall call) onDiscover;
  Future<List<TmdbGenreDto>> Function() onGenres;
  Future<TmdbMovieDto> Function(int movieId) onDetail;
  Future<TmdbMoviePageDto> Function(SearchCall call) onSearch;

  int popularCalls = 0;
  int genreCalls = 0;
  final discoverCalls = <DiscoverCall>[];
  final detailCalls = <int>[];
  final searchCalls = <SearchCall>[];

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) {
    popularCalls++;
    return onPopular(page);
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({
    required int page,
    List<int>? genreIds,
  }) {
    final call = (page: page, genreIds: genreIds);
    discoverCalls.add(call);
    return onDiscover(call);
  }

  @override
  Future<TmdbMoviePageDto> searchMovies({
    required int page,
    required String query,
  }) {
    final call = (page: page, query: query);
    searchCalls.add(call);
    return onSearch(call);
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() {
    genreCalls++;
    return onGenres();
  }

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) {
    detailCalls.add(movieId);
    return onDetail(movieId);
  }

  /// 실제 Service와 같은 규칙: 404만 null, 나머지 실패는 그대로 던진다.
  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    try {
      return await fetchMovieDetail(movieId);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<TmdbMoviePageDto> _defaultPopular(int page) async =>
      TmdbMoviePageDto.fromJson(pageJson(idRange(100, 20)));

  /// 페이지마다 20개, 500페이지까지 있는 것처럼 응답한다.
  static Future<TmdbMoviePageDto> _defaultDiscover(DiscoverCall call) async {
    final start = call.page * 1000;
    return TmdbMoviePageDto.fromJson(
      pageJson(idRange(start, 20), page: call.page),
    );
  }

  /// 검색어마다 페이지당 20개, 3페이지까지 있는 것처럼 응답한다.
  static Future<TmdbMoviePageDto> _defaultSearch(SearchCall call) async =>
      TmdbMoviePageDto.fromJson(
        pageJson(idRange(call.page * 1000, 20), page: call.page, totalPages: 3),
      );

  static Future<List<TmdbGenreDto>> _defaultGenres() async => [
    for (final genre in genresJson['genres']!) TmdbGenreDto.fromJson(genre),
  ];

  static Future<TmdbMovieDto> _defaultDetail(int movieId) async =>
      detailFor(movieId);

  /// 기본 상세 응답. 테스트가 onDetail을 바꾸면서도 기본값을 재사용할 수 있게 열어 둔다.
  static TmdbMovieDto detailFor(int movieId) =>
      TmdbMovieDto.fromJson(movieJson(movieId, title: '상세 $movieId'));
}

/// 서버가 응답하지 못한 상황을 흉내 낸 DioException.
DioException fakeDioError({int? statusCode}) {
  final options = RequestOptions(path: '/discover/movie');
  if (statusCode == null) {
    return DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'fake connection error',
    );
  }
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: statusCode),
  );
}
