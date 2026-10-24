// MovieLog 자체 API Service가 명세대로 요청하고, 오류를 화면용 문구로 바꾸는지 확인한다.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/movielog_client.dart';
import 'package:movielog/data/services/movielog_member_service.dart';

/// 경로별로 정해 둔 상태 코드·Body를 돌려주고, 들어온 요청을 기록한다.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.routes);

  final Map<String, (int, Object)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = routes[options.uri.path] ?? (404, const {});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  ({MovieLogMemberService service, StubAdapter adapter}) create(
    Map<String, (int, Object)> routes,
  ) {
    final dio = createMovieLogClient();
    final adapter = StubAdapter(routes);
    dio.httpClientAdapter = adapter;
    return (service: MovieLogMemberService(dio), adapter: adapter);
  }

  test('자체 API Client는 localhost:8080을 쓰고 TMDB Token을 붙이지 않는다', () async {
    final (:service, :adapter) = create({
      '/members/nickname/%ED%83%9C%EC%9D%B4': (200, {'available': true}),
    });

    expect(await service.checkNickname('태이'), isTrue);

    final request = adapter.requests.single;
    expect(request.baseUrl, 'http://localhost:8080');
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('이메일은 URL 인코딩해서 경로에 넣고 available을 읽는다', () async {
    final (:service, :adapter) = create({
      '/members/email/noco%40umc.com': (200, {'available': false}),
    });

    expect(await service.checkEmail('noco@umc.com'), isFalse);
  });

  test('유저별 평점을 DTO 목록으로 바꾼다', () async {
    final (:service, adapter: _) = create({
      '/members/1/ratings': (
        200,
        [
          {
            'ratingId': 2,
            'movieId': 155,
            'score': 4,
            'comment': '다시 봐도 명작',
            'createdAt': '2026-09-30T10:40:29',
            'updatedAt': '2026-09-30T10:40:29',
          },
        ],
      ),
    });

    final ratings = await service.fetchMemberRatings(1);

    expect(ratings.single.movieId, 155);
    expect(ratings.single.score, 4);
    expect(ratings.single.createdAt, DateTime(2026, 9, 30, 10, 40, 29));
  });

  test('400·404면 서버가 준 message를 그대로 담아 던진다', () async {
    final (:service, adapter: _) = create({
      '/members/nickname/a': (
        400,
        {'status': 400, 'message': '닉네임은 2~12자여야 합니다.'},
      ),
      '/members/999/ratings': (
        404,
        {'status': 404, 'message': '존재하지 않는 유저입니다.'},
      ),
    });

    await expectLater(
      service.checkNickname('a'),
      throwsA(
        isA<MovieLogApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', '닉네임은 2~12자여야 합니다.'),
      ),
    );
    await expectLater(
      service.fetchMemberRatings(999),
      throwsA(
        isA<MovieLogApiException>().having(
          (e) => e.message,
          'message',
          '존재하지 않는 유저입니다.',
        ),
      ),
    );
  });

  test('로그는 [MovieLog 요청] 형식으로 남는다', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);

    final (:service, adapter: _) = create({
      '/members/1/ratings': (200, <Object>[]),
    });
    await service.fetchMemberRatings(1);

    expect(
      logs,
      contains('[MovieLog 요청] GET http://localhost:8080/members/1/ratings'),
    );
  });
}
