import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'tmdb_fixtures.dart';

/// Discover 요청 한 번의 조건.
typedef DiscoverCall = ({int page, List<int>? genreIds});

/// 실제 서버 대신 fixture를 돌려주는 Service.
///
/// `implements`라서 Dio 없이 만들 수 있고, 어떤 요청이 들어왔는지 기록한다.
class FakeTmdbMovieService implements TmdbMovieService {
  FakeTmdbMovieService({
    Future<TmdbMoviePageDto> Function(int page)? onPopular,
    Future<TmdbMoviePageDto> Function(DiscoverCall call)? onDiscover,
    Future<List<TmdbGenreDto>> Function()? onGenres,
    Future<TmdbMovieDto> Function(int movieId)? onDetail,
  }) : onPopular = onPopular ?? _defaultPopular,
       onDiscover = onDiscover ?? _defaultDiscover,
       onGenres = onGenres ?? _defaultGenres,
       onDetail = onDetail ?? _defaultDetail;

  Future<TmdbMoviePageDto> Function(int page) onPopular;
  Future<TmdbMoviePageDto> Function(DiscoverCall call) onDiscover;
  Future<List<TmdbGenreDto>> Function() onGenres;
  Future<TmdbMovieDto> Function(int movieId) onDetail;

  int popularCalls = 0;
  int genreCalls = 0;
  final discoverCalls = <DiscoverCall>[];
  final detailCalls = <int>[];

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
  Future<List<TmdbGenreDto>> fetchGenres() {
    genreCalls++;
    return onGenres();
  }

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) {
    detailCalls.add(movieId);
    return onDetail(movieId);
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

  static Future<List<TmdbGenreDto>> _defaultGenres() async => [
    for (final genre in genresJson['genres']!) TmdbGenreDto.fromJson(genre),
  ];

  static Future<TmdbMovieDto> _defaultDetail(int movieId) async =>
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
