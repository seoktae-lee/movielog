// 워크북 서버(v5) Service가 명세대로 요청하고 응답을 모델로 바꾸는지 확인한다.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';

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
  ({Dio dio, StubAdapter adapter}) create(Map<String, (int, Object)> routes) {
    final dio = createMovieLogClient();
    final adapter = StubAdapter(routes);
    dio.httpClientAdapter = adapter;
    return (dio: dio, adapter: adapter);
  }

  group('모델', () {
    test('CheckResult는 Wrapper 없이 body를 그대로 읽는다', () {
      expect(CheckResult.fromJson({'available': false}).available, isFalse);
    });

    test('RatingDto는 comment가 null이어도 만들어진다', () {
      final rating = RatingDto.fromJson({
        'ratingId': 3,
        'movieId': 13,
        'score': 3,
        'comment': null,
        'createdAt': '2026-10-23T19:00:08.826Z',
        'updatedAt': '2026-10-23T19:00:08.826Z',
      });

      expect(rating.comment, isNull);
      expect(rating.movieId, 13);
      expect(rating.createdAt.isUtc, isTrue);
    });
  });

  test('워크북 Client는 workbook.devnoco.com을 쓰고 TMDB Token을 붙이지 않는다', () async {
    final (:dio, :adapter) = create({
      '/v5/members/nickname/%EC%98%81%ED%99%94%EA%B4%91': (
        200,
        {'available': false},
      ),
    });

    expect(await MemberCheckService(dio).checkNickname(' 영화광 '), isFalse);

    final request = adapter.requests.single;
    expect(request.baseUrl, 'https://workbook.devnoco.com');
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('이메일은 URL 인코딩해서 경로에 넣는다', () async {
    final (:dio, :adapter) = create({
      '/v5/members/email/movie%40umc.com': (200, {'available': true}),
    });

    expect(await MemberCheckService(dio).checkEmail('movie@umc.com'), isTrue);
  });

  test('유저별 평점: 배열을 RatingDto 목록으로, 빈 배열은 빈 목록으로', () async {
    final (:dio, adapter: _) = create({
      '/v5/members/1/ratings': (
        200,
        [
          {
            'ratingId': 1,
            'movieId': 550,
            'score': 5,
            'comment': '최고의 영화!',
            'createdAt': '2026-09-06T12:14:03.000Z',
            'updatedAt': '2026-09-06T12:14:03.000Z',
          },
        ],
      ),
      '/v5/members/3/ratings': (200, <Object>[]),
    });
    final service = RatingApiService(dio);

    final ratings = await service.fetchMyRatings(1);
    expect(ratings.single.movieId, 550);
    expect(ratings.single.comment, '최고의 영화!');

    expect(await service.fetchMyRatings(3), isEmpty);
  });

  test('400·404·연결 실패를 서로 다른 문구로 바꾼다', () async {
    final (:dio, adapter: _) = create({
      '/v5/members/4/ratings': (
        404,
        {'message': '존재하지 않는 유저입니다.', 'error': 'Not Found', 'statusCode': 404},
      ),
    });

    try {
      await RatingApiService(dio).fetchMyRatings(4);
      fail('404면 DioException을 던져야 한다');
    } on DioException catch (error) {
      expect(writeMyRatingsErrorMessage(error), '존재하지 않는 회원입니다.');
    }

    DioException withStatus(int? status) => DioException(
      requestOptions: RequestOptions(),
      response: status == null
          ? null
          : Response(requestOptions: RequestOptions(), statusCode: status),
    );
    expect(
      writeMyRatingsErrorMessage(withStatus(400)),
      'memberId 형식을 다시 확인해 주세요.',
    );
    expect(
      writeMyRatingsErrorMessage(withStatus(null)),
      '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
    );
  });

  test('로그는 [MovieLog 요청] 형식으로 남는다', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);

    final (:dio, adapter: _) = create({
      '/v5/members/1/ratings': (200, <Object>[]),
    });
    await RatingApiService(dio).fetchMyRatings(1);

    expect(
      logs,
      contains(
        '[MovieLog 요청] GET https://workbook.devnoco.com/v5/members/1/ratings',
      ),
    );
  });
}
