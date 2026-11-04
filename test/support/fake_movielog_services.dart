import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';

/// 실제 워크북 서버 대신 정해 둔 값을 돌려주는 회원가입 Service.
class FakeSignUpService implements SignUpService {
  FakeSignUpService({
    this.takenNicknames = const {'영화광'},
    this.takenEmails = const {'movie@umc.com'},
  });

  final Set<String> takenNicknames;
  final Set<String> takenEmails;

  /// null이 아니면 모든 요청이 이 예외로 실패한다. (통신 실패 흉내)
  DioException? error;

  /// null이 아니면 회원가입 POST만 이 예외로 실패한다. (400·409 흉내)
  DioException? signUpError;

  /// 회원가입 성공 시 돌려줄 memberId. null이면 result 없는 201(계약 오류)을 흉내 낸다.
  int? createdMemberId = 42;

  /// null이 아니면 응답을 이 Completer가 끝날 때까지 붙잡아 둔다. (통신 중 상태 확인용)
  Completer<void>? gate;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];
  final signUpCalls = <CreateMemberRequest>[];

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

  @override
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    signUpCalls.add(request);
    await gate?.future;
    if (error != null) throw error!;
    if (signUpError != null) throw signUpError!;
    final id = createdMemberId;
    return CommonResponse(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입에 성공했습니다.',
      result: id == null
          ? null
          : SignUpResult(
              memberId: id,
              email: request.email.trim(),
              nickname: request.nickname.trim(),
            ),
    );
  }
}

/// 실제 워크북 서버 대신 메모리 목록으로 평점 CRUD를 흉내 내는 Service.
class FakeRatingApiService implements RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings})
    : ratings = List.of(ratings ?? defaultRatings);

  List<RatingDto> ratings;

  /// 조회(GET) 실패.
  DioException? error;

  /// 쓰기(POST·PATCH·DELETE) 실패. ratingId별로 다르게 주려면 [writeErrorFor].
  DioException? writeError;
  DioException? Function(int ratingId)? writeErrorFor;

  /// null이 아니면 쓰기 응답을 붙잡아 둔다. (저장 중 상태 확인용)
  Completer<void>? writeGate;

  final calls = <int>[];
  final createCalls = <(int, CreateRatingRequest)>[];
  final updateCalls = <(int, int, int, String?)>[];
  final deleteCalls = <(int, int)>[];

  /// v6 `/members/1/ratings` 실제 응답과 같은 모양 (ratingId 내림차순).
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
    return List.of(ratings);
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    createCalls.add((memberId, request));
    await writeGate?.future;
    if (writeError != null) throw writeError!;
    final nextId = ratings.isEmpty
        ? 1
        : ratings.map((r) => r.ratingId).reduce((a, b) => a > b ? a : b) + 1;
    ratings = [
      _rating(nextId, request.movieId, request.score, request.comment),
      ...ratings,
    ];
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    updateCalls.add((memberId, ratingId, score, comment));
    await writeGate?.future;
    final failure = writeErrorFor?.call(ratingId) ?? writeError;
    if (failure != null) throw failure;
    ratings = [
      for (final r in ratings)
        r.ratingId == ratingId
            ? _rating(r.ratingId, r.movieId, score, comment)
            : r,
    ];
  }

  @override
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    deleteCalls.add((memberId, ratingId));
    await writeGate?.future;
    final failure = writeErrorFor?.call(ratingId) ?? writeError;
    if (failure != null) throw failure;
    ratings = [
      for (final r in ratings)
        if (r.ratingId != ratingId) r,
    ];
  }

  static RatingDto _rating(int id, int movieId, int score, String? comment) =>
      RatingDto.fromJson({
        'ratingId': id,
        'movieId': movieId,
        'score': score,
        'comment': comment,
        'createdAt': '2026-10-28T10:00:00.000Z',
        'updatedAt': '2026-10-28T10:00:00.000Z',
      });
}

/// 상태 코드가 있는 실패(400·404 등) 또는 연결 실패(null)를 흉내 낸 DioException.
///
/// [code]·[message]를 주면 v6 공통 실패 응답 body(`isSuccess/code/message/result`)를 담는다.
DioException fakeMovieLogError({
  int? statusCode,
  String path = '/v6',
  String? code,
  String? message,
}) {
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
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: code == null
          ? null
          : {
              'isSuccess': false,
              'code': code,
              'message': message ?? '',
              'result': null,
            },
    ),
  );
}
