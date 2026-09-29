// Service가 올바른 경로·Query·Header로 요청하는지, 로그가 Token을 가리는지 확인한다.
//
// 실제 네트워크 대신 Dio의 HttpClientAdapter를 바꿔 끼워 요청을 기록하고 fixture를 돌려준다.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/config/tmdb_config.dart';
import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/core/network/tmdb_logging_interceptor.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'support/tmdb_fixtures.dart';

/// 요청을 기록하고, 경로에 맞는 fixture JSON을 200으로 돌려준다.
class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = switch (options.path) {
      '/genre/movie/list' => genresJson,
      _ => pageJson(idRange(1, 20)),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const fakeToken = 'test-token-should-never-be-logged';

  setUp(() {
    dotenv.loadFromString(envString: '${TmdbConfig.accessTokenKey}=$fakeToken');
  });

  ({TmdbMovieService service, RecordingAdapter adapter}) createService() {
    final dio = createTmdbClient();
    final adapter = RecordingAdapter();
    dio.httpClientAdapter = adapter;
    return (service: TmdbMovieService(dio), adapter: adapter);
  }

  test('TMDB Client는 .env의 Token을 Bearer Header로 붙인다', () async {
    final (:service, :adapter) = createService();

    await service.fetchPopular();

    final request = adapter.requests.single;
    expect(
      request.uri.toString(),
      startsWith('https://api.themoviedb.org/3/movie/popular'),
    );
    expect(request.headers['Authorization'], 'Bearer $fakeToken');
    expect(request.queryParameters, {'language': 'ko-KR', 'page': 1});
  });

  test('전체(장르 없음)이면 with_genres를 보내지 않는다', () async {
    final (:service, :adapter) = createService();

    await service.discoverMovies(page: 1);
    await service.discoverMovies(page: 2, genreIds: const []);

    for (final request in adapter.requests) {
      expect(request.path, '/discover/movie');
      expect(request.queryParameters.containsKey('with_genres'), isFalse);
      expect(request.queryParameters['sort_by'], 'popularity.desc');
      expect(request.queryParameters['include_adult'], false);
    }
    expect(adapter.requests.map((r) => r.queryParameters['page']), [1, 2]);
  });

  test('장르 여러 개는 | (OR)로 이어 with_genres에 담는다', () async {
    final (:service, :adapter) = createService();

    await service.discoverMovies(page: 1, genreIds: const [28, 12]);

    expect(adapter.requests.single.queryParameters['with_genres'], '28|12');
  });

  test('Genre API 응답을 장르 DTO 목록으로 바꾼다', () async {
    final (:service, :adapter) = createService();

    final genres = await service.fetchGenres();

    expect(adapter.requests.single.queryParameters, {'language': 'ko'});
    expect(genres.map((genre) => genre.name), ['액션', '모험', '애니메이션', '드라마']);
  });

  test('로그에는 Authorization 원문 대신 Bearer ***만 남는다', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);

    final (:service, adapter: _) = createService();
    await service.discoverMovies(page: 1, genreIds: const [28]);

    final all = logs.join('\n');
    expect(all, contains('[TMDB 요청] GET'));
    expect(all, contains('[TMDB 요청 Header]'));
    expect(all, contains('Bearer ***'));
    expect(all, contains('[TMDB 응답] 200'));
    expect(all, isNot(contains(fakeToken)));
  });

  test('마스킹은 복사본에만 적용되고 실제 요청 Header는 바꾸지 않는다', () {
    final headers = <String, dynamic>{'Authorization': 'Bearer $fakeToken'};

    final masked = TmdbLoggingInterceptor.maskHeaders(headers);

    expect(masked['Authorization'], 'Bearer ***');
    expect(headers['Authorization'], 'Bearer $fakeToken');
  });
}
