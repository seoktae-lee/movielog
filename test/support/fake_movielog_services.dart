import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';

/// 실제 워크북 서버 대신 정해 둔 값을 돌려주는 중복 확인 Service.
class FakeMemberCheckService implements MemberCheckService {
  FakeMemberCheckService({
    this.takenNicknames = const {'영화광'},
    this.takenEmails = const {'movie@umc.com'},
  });

  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  /// null이 아니면 모든 요청이 이 예외로 실패한다. (통신 실패 흉내)
  DioException? error;

  /// null이 아니면 응답을 이 Completer가 끝날 때까지 붙잡아 둔다. (통신 중 상태 확인용)
  Completer<void>? gate;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls.add(nickname);
    await gate?.future;
    if (error != null) throw error!;
    return !takenNicknames.contains(nickname);
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email);
    await gate?.future;
    if (error != null) throw error!;
    return !takenEmails.contains(email);
  }
}

/// 실제 워크북 서버 대신 정해 둔 평점을 돌려주는 Service.
class FakeRatingApiService implements RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings})
    : ratings = ratings ?? defaultRatings;

  List<RatingDto> ratings;
  DioException? error;
  final calls = <int>[];

  /// v5 `/members/1/ratings` 실제 응답과 같은 모양 (ratingId 내림차순).
  static final defaultRatings = [
    RatingDto.fromJson(const {
      'ratingId': 3,
      'movieId': 13,
      'score': 3,
      'comment': null,
      'createdAt': '2026-10-23T19:00:08.826Z',
      'updatedAt': '2026-10-23T19:00:08.826Z',
    }),
    RatingDto.fromJson(const {
      'ratingId': 2,
      'movieId': 680,
      'score': 4,
      'comment': '다시 봐도 좋다',
      'createdAt': '2026-10-23T19:00:08.826Z',
      'updatedAt': '2026-10-23T19:00:08.826Z',
    }),
    RatingDto.fromJson(const {
      'ratingId': 1,
      'movieId': 550,
      'score': 5,
      'comment': '최고의 영화!',
      'createdAt': '2026-10-23T19:00:08.826Z',
      'updatedAt': '2026-10-23T19:00:08.826Z',
    }),
  ];

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    calls.add(memberId);
    if (error != null) throw error!;
    return ratings;
  }
}

/// 상태 코드가 있는 실패(400·404 등) 또는 연결 실패(null)를 흉내 낸 DioException.
DioException fakeMovieLogError({int? statusCode, String path = '/v5'}) {
  final options = RequestOptions(path: path);
  if (statusCode == null) {
    return DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: statusCode),
  );
}
