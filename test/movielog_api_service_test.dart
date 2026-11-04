// 워크북 서버(v6) Service가 명세대로 요청하고 응답을 모델로 바꾸는지 확인한다.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

import 'support/fake_movielog_services.dart';

/// 경로별로 정해 둔 상태 코드·Body를 돌려주고, 들어온 요청을 기록한다.
///
/// Key는 `'METHOD /path'`(먼저 찾음) 또는 `'/path'`. Body가 null이면 본문 없이 응답한다. (204)
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.routes);

  final Map<String, (int, Object?)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    final (status, body) =
        routes['${options.method} $path'] ?? routes[path] ?? (404, const {});
    if (body == null) return ResponseBody.fromString('', status);
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
  ({Dio dio, StubAdapter adapter}) create(Map<String, (int, Object?)> routes) {
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
      '/v6/members/nickname/%EC%98%81%ED%99%94%EA%B4%91': (
        200,
        {'available': false},
      ),
    });

    expect(await SignUpService(dio).checkNickname(' 영화광 '), isFalse);

    final request = adapter.requests.single;
    expect(request.baseUrl, 'https://workbook.devnoco.com');
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('이메일은 URL 인코딩해서 경로에 넣는다', () async {
    final (:dio, :adapter) = create({
      '/v6/members/email/movie%40umc.com': (200, {'available': true}),
    });

    expect(await SignUpService(dio).checkEmail('movie@umc.com'), isTrue);
  });

  test('유저별 평점: 배열을 RatingDto 목록으로, 빈 배열은 빈 목록으로', () async {
    final (:dio, adapter: _) = create({
      '/v6/members/1/ratings': (
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
      '/v6/members/3/ratings': (200, <Object>[]),
    });
    final service = RatingApiService(dio);

    final ratings = await service.fetchMyRatings(1);
    expect(ratings.single.movieId, 550);
    expect(ratings.single.comment, '최고의 영화!');

    expect(await service.fetchMyRatings(3), isEmpty);
  });

  test('400·404·연결 실패를 서로 다른 문구로 바꾼다', () async {
    final (:dio, adapter: _) = create({
      // v6 실패는 공통 형식으로 감싸진다.
      '/v6/members/4/ratings': (
        404,
        {
          'isSuccess': false,
          'code': 'COMMON404',
          'message': '존재하지 않는 유저입니다.',
          'result': null,
        },
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
      '/v6/members/1/ratings': (200, <Object>[]),
    });
    await RatingApiService(dio).fetchMyRatings(1);

    expect(
      logs,
      contains(
        '[MovieLog 요청] GET https://workbook.devnoco.com/v6/members/1/ratings',
      ),
    );
  });

  group('7주차 요청·응답 Model', () {
    test('CommonResponse는 result를 parseResult로, null이면 호출하지 않는다', () {
      var called = 0;
      final ok = CommonResponse<int>.fromJson(
        {'isSuccess': true, 'code': 'COMMON201', 'message': 'ok', 'result': 7},
        (value) {
          called++;
          return value as int;
        },
      );
      expect(ok.result, 7);

      final empty = CommonResponse<int>.fromJson(
        {
          'isSuccess': true,
          'code': 'COMMON200',
          'message': 'ok',
          'result': null,
        },
        (value) {
          called++;
          return value as int;
        },
      );
      expect(empty.result, isNull);
      expect(called, 1);
    });

    test('CreateMemberRequest: 이메일·닉네임만 trim, 비밀번호는 그대로이고 로그에 남지 않는다', () {
      const request = CreateMemberRequest(
        email: ' a@b.com ',
        password: ' Pass1234! ',
        nickname: ' 태이 ',
      );
      expect(request.toJson(), {
        'email': 'a@b.com',
        'password': ' Pass1234! ',
        'nickname': '태이',
      });
      expect(request.toString(), isNot(contains('Pass1234')));
    });

    test('CreateRatingRequest: comment가 비면 키를 생략, 있으면 trim', () {
      expect(const CreateRatingRequest(movieId: 550, score: 4).toJson(), {
        'movieId': 550,
        'score': 4,
      });
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: '  ',
        ).toJson(),
        {'movieId': 550, 'score': 4},
      );
      expect(
        const CreateRatingRequest(
          movieId: 550,
          score: 4,
          comment: ' 좋아요 ',
        ).toJson()['comment'],
        '좋아요',
      );
    });

    test('UpdateRatingRequest는 comment가 null이어도 키를 보낸다 (전체 교체 계약)', () {
      expect(const UpdateRatingRequest(score: 2, comment: null).toJson(), {
        'score': 2,
        'comment': null,
      });
    });

    test('validateServerScore는 1~5 정수만 통과시킨다', () {
      expect(validateServerScore(3.0), 3);
      expect(() => validateServerScore(3.5), throwsArgumentError);
      expect(() => validateServerScore(0), throwsArgumentError);
      expect(() => validateServerScore(6), throwsArgumentError);
    });
  });

  group('7주차 쓰기 API', () {
    test('회원가입 POST: body를 보내고 CommonResponse<SignUpResult>로 읽는다', () async {
      final (:dio, :adapter) = create({
        'POST /v6/members': (
          201,
          {
            'isSuccess': true,
            'code': 'COMMON201',
            'message': '회원가입에 성공했습니다.',
            'result': {'memberId': 42, 'email': 'a@b.com', 'nickname': '태이'},
          },
        ),
      });

      final response = await SignUpService(dio).signUp(
        const CreateMemberRequest(
          email: 'a@b.com',
          password: 'Pass1234!',
          nickname: '태이',
        ),
      );

      expect(response.code, 'COMMON201');
      expect(response.result?.memberId, 42);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect((request.data as Map)['email'], 'a@b.com');
    });

    test('회원가입 409는 서버 message를 그대로 문구로 쓴다', () async {
      final (:dio, adapter: _) = create({
        'POST /v6/members': (
          409,
          {
            'isSuccess': false,
            'code': 'COMMON409',
            'message': '이미 사용 중인 이메일입니다.',
            'result': null,
          },
        ),
      });
      try {
        await SignUpService(dio).signUp(
          const CreateMemberRequest(
            email: 'movie@umc.com',
            password: 'Pass1234!',
            nickname: '태이',
          ),
        );
        fail('409면 DioException');
      } on DioException catch (error) {
        expect(writeSignUpErrorMessage(error), '이미 사용 중인 이메일입니다.');
      }
      expect(
        writeSignUpErrorMessage(fakeMovieLogError()),
        '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      );
    });

    test('평점 등록 201: result를 파싱하지 않고(null이어도) 성공', () async {
      final (:dio, :adapter) = create({
        'POST /v6/members/42/ratings': (
          201,
          {
            'isSuccess': true,
            'code': 'COMMON201',
            'message': '평점 등록에 성공했습니다.',
            'result': null,
          },
        ),
      });

      await RatingApiService(dio).createRating(
        memberId: 42,
        request: const CreateRatingRequest(
          movieId: 550,
          score: 5,
          comment: '최고',
        ),
      );
      expect(adapter.requests.single.data, {
        'movieId': 550,
        'score': 5,
        'comment': '최고',
      });
    });

    test('평점 수정 PATCH: score와 comment(null 포함)를 함께 보낸다', () async {
      final (:dio, :adapter) = create({
        'PATCH /v6/members/42/ratings/7': (
          200,
          {
            'isSuccess': true,
            'code': 'COMMON200',
            'message': 'ok',
            'result': null,
          },
        ),
      });

      await RatingApiService(dio)
          .updateRating(memberId: 42, ratingId: 7, score: 2, comment: null);
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.data, {'score': 2, 'comment': null});
    });

    test('평점 삭제 204: 본문이 없어도 파싱 오류 없이 끝난다', () async {
      final (:dio, :adapter) = create({
        'DELETE /v6/members/42/ratings/7': (204, null),
      });

      await RatingApiService(dio).deleteRating(memberId: 42, ratingId: 7);
      expect(adapter.requests.single.method, 'DELETE');
    });

    test('쓰기 오류: message는 그대로, 403·404만 재조회 대상', () {
      final e400 = fakeMovieLogError(
        statusCode: 400,
        code: 'COMMON400',
        message: '별점은 5점 이하여야 합니다.',
      );
      final e403 = fakeMovieLogError(
        statusCode: 403,
        code: 'COMMON403',
        message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );
      final e404 = fakeMovieLogError(
        statusCode: 404,
        code: 'COMMON404',
        message: '존재하지 않는 평점입니다.',
      );
      final e409 = fakeMovieLogError(
        statusCode: 409,
        code: 'COMMON409',
        message: '이미 이 영화에 평점을 남기셨습니다.',
      );

      expect(writeErrorMessage(e400), '별점은 5점 이하여야 합니다.');
      expect(writeErrorMessage(e403), '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.');
      expect(writeErrorMessage(e404), '존재하지 않는 평점입니다.');
      expect(writeErrorMessage(e409), '이미 이 영화에 평점을 남기셨습니다.');
      expect(writeErrorMessage(fakeMovieLogError()), contains('잠시 후 다시'));

      expect(shouldRefreshAfterRatingError(e400), isFalse);
      expect(shouldRefreshAfterRatingError(e403), isTrue);
      expect(shouldRefreshAfterRatingError(e404), isTrue);
      expect(shouldRefreshAfterRatingError(e409), isFalse);
    });
  });
}
