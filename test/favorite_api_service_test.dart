// 9주차 Service가 /v8 명세대로 요청하고 응답을 모델로 바꾸는지 확인한다.
// (즐겨찾기 4개 API, 영화 기록 저장, TMDB 검색, 보호 경로 판정)

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

import 'support/fake_movielog_services.dart';
import 'support/stub_adapter.dart';
import 'support/tmdb_fixtures.dart';

Map<String, Object?> ok(String code, String message, Object? result) => {
  'isSuccess': true,
  'code': code,
  'message': message,
  'result': result,
};

void main() {
  ({Dio dio, StubAdapter adapter}) create(Map<String, (int, Object?)> routes) {
    final dio = createMovieLogClient();
    final adapter = StubAdapter(routes);
    dio.httpClientAdapter = adapter;
    return (dio: dio, adapter: adapter);
  }

  group('FavoriteApiService', () {
    test('등록: POST /v8/favorites에 movieId만 보내고 201 result를 읽는다', () async {
      final (:dio, :adapter) = create({
        'POST /v8/favorites': (
          201,
          ok('COMMON201', '등록', {
            'favoriteId': 3,
            'movieId': 550,
            'createdAt': '2026-09-06T12:14:03.000Z',
          }),
        ),
      });

      final favorite = await FavoriteApiService(dio).addFavorite(movieId: 550);

      expect(adapter.requests.single.data, {'movieId': 550});
      expect(favorite.favoriteId, 3);
      expect(favorite.movieId, 550);
      expect(favorite.createdAt.isUtc, isTrue);
    });

    test('내 목록: GET /v8/favorites, result 배열을 읽고 없으면 빈 배열', () async {
      final (:dio, :adapter) = create({
        'GET /v8/favorites': (
          200,
          ok('COMMON200', '조회', [
            {
              'favoriteId': 3,
              'movieId': 550,
              'createdAt': '2026-09-06T12:14:03.000Z',
            },
          ]),
        ),
      });
      final list = await FavoriteApiService(dio).fetchMyFavorites();
      expect(list.single.movieId, 550);
      // 즐겨찾기 API에는 page·memberId 파라미터가 없다.
      expect(adapter.requests.single.uri.query, isEmpty);

      final empty = create({
        'GET /v8/favorites': (200, ok('COMMON200', '조회', <Object?>[])),
      });
      expect(await FavoriteApiService(empty.dio).fetchMyFavorites(), isEmpty);
    });

    test(
      '여부 조회: 경로는 favoriteId가 아니라 movieId, 응답에 없는 movieId는 요청값으로 채운다',
      () async {
        final (:dio, :adapter) = create({
          'GET /v8/favorites/550': (
            200,
            ok('COMMON200', '조회', {'isFavorite': true}),
          ),
        });

        final FavoriteCheckDto check = await FavoriteApiService(dio)
            .checkFavorite(movieId: 550);

        expect(adapter.requests.single.uri.path, '/v8/favorites/550');
        expect(check.isFavorite, isTrue);
        expect(check.movieId, 550);
      },
    );

    test('여부 응답에 isFavorite가 boolean이 아니면 FormatException', () {
      expect(
        () => FavoriteCheckDto.fromJson({'isFavorite': 'yes'}, movieId: 1),
        throwsFormatException,
      );
    });

    test('해제: DELETE는 200 + result null이고 예외가 없으면 성공 (204가 아니다)', () async {
      final (:dio, :adapter) = create({
        'DELETE /v8/favorites/550': (200, ok('COMMON200', '해제', null)),
      });

      await FavoriteApiService(dio).deleteFavorite(movieId: 550);

      expect(adapter.requests.single.method, 'DELETE');
    });

    test('409·404 실패는 DioException이고 code를 읽을 수 있다', () async {
      final (:dio, adapter: _) = create({
        'POST /v8/favorites': (
          409,
          {
            'isSuccess': false,
            'code': 'FAVORITE409_1',
            'message': '이미 즐겨찾기',
            'result': null,
          },
        ),
      });

      await expectLater(
        FavoriteApiService(dio).addFavorite(movieId: 550),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.data['code'],
            'code',
            'FAVORITE409_1',
          ),
        ),
      );
    });
  });

  group('MovieRecordApiService (Challenge)', () {
    test('addToFavorites는 false여도 항상 보내고, comment가 없으면 생략한다', () {
      expect(
        const MovieRecordRequest(
          movieId: 550,
          score: 3,
          addToFavorites: false,
        ).toJson(),
        {'movieId': 550, 'score': 3, 'addToFavorites': false},
      );
      expect(
        const MovieRecordRequest(
          movieId: 550,
          score: 3,
          comment: '  후기  ',
          addToFavorites: true,
        ).toJson(),
        {'movieId': 550, 'score': 3, 'comment': '후기', 'addToFavorites': true},
      );
    });

    test('POST /v8/movie-records: result의 rating과 favorite을 읽는다', () async {
      final (:dio, :adapter) = create({
        'POST /v8/movie-records': (
          201,
          ok('COMMON201', '저장', {
            'rating': {
              'ratingId': 1,
              'movieId': 550,
              'score': 3,
              'comment': '후기',
              'createdAt': '2026-09-06T12:14:03.000Z',
            },
            'favorite': {
              'favoriteId': 9,
              'movieId': 550,
              'createdAt': '2026-09-06T12:14:03.000Z',
            },
          }),
        ),
      });

      final saved = await MovieRecordApiService(dio).saveMovieRecord(
        const MovieRecordRequest(
          movieId: 550,
          score: 3,
          comment: '후기',
          addToFavorites: true,
        ),
      );

      expect(adapter.requests.single.uri.path, '/v8/movie-records');
      expect(saved.rating.score, 3);
      expect(saved.favorite?.favoriteId, 9);
    });

    test('addToFavorites=false면 favorite이 null인 것이 정상이다', () async {
      final (:dio, adapter: _) = create({
        'POST /v8/movie-records': (
          201,
          ok('COMMON201', '저장', {
            'rating': {
              'ratingId': 1,
              'movieId': 550,
              'score': 3,
              'comment': null,
              'createdAt': '2026-09-06T12:14:03.000Z',
            },
            'favorite': null,
          }),
        ),
      });

      final saved = await MovieRecordApiService(dio).saveMovieRecord(
        const MovieRecordRequest(movieId: 550, score: 3, addToFavorites: false),
      );

      expect(saved.favorite, isNull);
    });
  });

  group('TmdbMovieService.searchMovies', () {
    test('query·page·language를 보내고 page 응답으로 바꾼다', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org'));
      final adapter = StubAdapter({
        '/search/movie': (200, pageJson([1, 2], page: 2, totalPages: 7)),
      });
      dio.httpClientAdapter = adapter;

      final page = await TmdbMovieService(dio)
          .searchMovies(page: 2, query: '어벤져스');

      final query = adapter.requests.single.queryParameters;
      expect(query['query'], '어벤져스');
      expect(query['page'], 2);
      expect(query['language'], 'ko-KR');
      expect(page.page, 2);
      expect(page.totalPages, 7);
    });

    test('빈 검색어는 서버에 보내지 않는다', () async {
      final dio = Dio();
      final adapter = StubAdapter(const {});
      dio.httpClientAdapter = adapter;

      await expectLater(
        TmdbMovieService(dio).searchMovies(page: 1, query: '  '),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('AuthInterceptor.isProtected (v8)', () {
    Uri u(String path, {String host = 'workbook.devnoco.com'}) =>
        Uri.parse('https://$host$path');

    test('즐겨찾기: 등록·목록(/v8/favorites)과 여부 조회·해제(/v8/favorites/{movieId})', () {
      expect(AuthInterceptor.isProtected(u('/v8/favorites'), 'POST'), isTrue);
      expect(AuthInterceptor.isProtected(u('/v8/favorites'), 'GET'), isTrue);
      expect(
        AuthInterceptor.isProtected(u('/v8/favorites/550'), 'GET'),
        isTrue,
      );
      expect(
        AuthInterceptor.isProtected(u('/v8/favorites/550'), 'DELETE'),
        isTrue,
      );
    });

    test('method가 맞지 않거나 movieId가 양수가 아니면 보호 요청이 아니다', () {
      expect(
        AuthInterceptor.isProtected(u('/v8/favorites'), 'DELETE'),
        isFalse,
      );
      expect(
        AuthInterceptor.isProtected(u('/v8/favorites/550'), 'POST'),
        isFalse,
      );
      expect(AuthInterceptor.isProtected(u('/v8/favorites/0'), 'GET'), isFalse);
      expect(
        AuthInterceptor.isProtected(u('/v8/favorites/abc'), 'GET'),
        isFalse,
      );
    });

    test('영화 기록은 POST만, 8주차 보호 경로는 v8로 이어진다', () {
      expect(
        AuthInterceptor.isProtected(u('/v8/movie-records'), 'POST'),
        isTrue,
      );
      expect(
        AuthInterceptor.isProtected(u('/v8/movie-records'), 'GET'),
        isFalse,
      );
      expect(AuthInterceptor.isProtected(u('/v8/members/me'), 'GET'), isTrue);
      expect(AuthInterceptor.isProtected(u('/v8/ratings/3'), 'PATCH'), isTrue);
      // 이전 v7 경로는 더 이상 보호 대상이 아니다.
      expect(AuthInterceptor.isProtected(u('/v7/ratings'), 'POST'), isFalse);
    });

    test('공개 API(로그인·가입·유저별 평점)와 다른 호스트에는 토큰을 붙이지 않는다', () {
      expect(AuthInterceptor.isProtected(u('/v8/auth/login'), 'POST'), isFalse);
      expect(AuthInterceptor.isProtected(u('/v8/members'), 'POST'), isFalse);
      expect(
        AuthInterceptor.isProtected(u('/v8/members/1/ratings'), 'GET'),
        isFalse,
      );
      expect(
        AuthInterceptor.isProtected(
          u('/v8/favorites', host: 'api.themoviedb.org'),
          'GET',
        ),
        isFalse,
      );
    });

    test('보호용 Client는 즐겨찾기 요청에만 Authorization을 붙인다', () async {
      final storage = InMemoryTokenStorage('jwt-123');
      final dio = createAuthMovieLogClient(storage);
      final adapter = StubAdapter({
        '/v8/favorites': (200, ok('COMMON200', '조회', <Object?>[])),
        '/v8/members/1/ratings': (200, <Object?>[]),
      });
      dio.httpClientAdapter = adapter;

      await dio.get('/v8/favorites');
      await dio.get('/v8/members/1/ratings');

      expect(adapter.requests[0].headers['Authorization'], 'Bearer jwt-123');
      expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
    });
  });
}
