import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/core/storage/email_preferences.dart';
import 'package:movielog/core/storage/install_marker.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
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

/// 실제 워크북 서버 대신 메모리 목록으로 v7 평점 CRUD를 흉내 내는 Service.
class FakeRatingApiService implements RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings})
    : ratings = List.of(ratings ?? const []);

  /// 서버에 있다고 가정한 평점들.
  List<RatingDto> ratings;

  /// 공개 조회(GET) 실패.
  DioException? error;

  /// 쓰기(POST·PATCH·DELETE) 실패. ratingId별로 다르게 주려면 [writeErrorFor].
  DioException? writeError;
  DioException? Function(int ratingId)? writeErrorFor;

  /// null이 아니면 쓰기 응답을 붙잡아 둔다. (저장 중 상태 확인용)
  Completer<void>? writeGate;

  final calls = <int>[];
  final createCalls = <CreateRatingRequest>[];
  final updateCalls = <(int, int, String?)>[];
  final deleteCalls = <int>[];

  @override
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    calls.add(memberId);
    if (error != null) throw error!;
    return List.of(ratings);
  }

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    createCalls.add(request);
    await writeGate?.future;
    if (writeError != null) throw writeError!;
    final nextId = ratings.isEmpty
        ? 1
        : ratings.map((r) => r.ratingId).reduce((a, b) => a > b ? a : b) + 1;
    final created = fakeRating(
      nextId,
      request.movieId,
      request.score,
      request.comment,
    );
    ratings = [created, ...ratings];
    return created;
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    updateCalls.add((ratingId, score, comment));
    await writeGate?.future;
    final failure = writeErrorFor?.call(ratingId) ?? writeError;
    if (failure != null) throw failure;
    final old = ratings.firstWhere((r) => r.ratingId == ratingId);
    final updated = fakeRating(ratingId, old.movieId, score, comment);
    ratings = [for (final r in ratings) r.ratingId == ratingId ? updated : r];
    return updated;
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    deleteCalls.add(ratingId);
    await writeGate?.future;
    final failure = writeErrorFor?.call(ratingId) ?? writeError;
    if (failure != null) throw failure;
    ratings = [
      for (final r in ratings)
        if (r.ratingId != ratingId) r,
    ];
  }
}

RatingDto fakeRating(int id, int movieId, int score, String? comment) =>
    RatingDto.fromJson({
      'ratingId': id,
      'movieId': movieId,
      'score': score,
      'comment': comment,
      'createdAt': '2026-11-09T10:00:00.000Z',
      'updatedAt': '2026-11-09T10:00:00.000Z',
    });

/// 메모리에만 두는 토큰 저장소. [failRead] 등으로 기기 저장소 실패를 흉내 낸다.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.token]);

  String? token;
  bool failRead = false;
  bool failWrite = false;
  int deleteCount = 0;

  @override
  Future<void> saveAccessToken(String token) async {
    if (failWrite) throw StateError('write failed');
    this.token = token;
  }

  @override
  Future<String?> readAccessToken() async {
    if (failRead) throw StateError('read failed');
    return token;
  }

  @override
  Future<void> deleteAccessToken() async {
    deleteCount++;
    token = null;
  }
}

class FakeAuthApiService implements AuthApiService {
  /// 이 비밀번호면 성공, 아니면 AUTH401_1.
  String correctPassword = 'Umc1234!';
  String issuedToken = 'token-1';

  /// null이 아니면 모든 로그인이 이 예외로 실패한다. (통신 실패 등)
  DioException? error;
  Completer<void>? gate;
  final calls = <LoginRequest>[];

  @override
  Future<LoginResult> login(LoginRequest request) async {
    calls.add(request);
    await gate?.future;
    if (error != null) throw error!;
    if (request.password != correctPassword) {
      throw fakeMovieLogError(
        statusCode: 401,
        code: 'AUTH401_1',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
      );
    }
    return LoginResult(nickname: '태이', accessToken: issuedToken);
  }
}

class FakeMemberApiService implements MemberApiService {
  FakeMemberApiService({MemberInfo? member})
    : member =
          member ??
          MemberInfo(
            email: 'taei@movielog.dev',
            nickname: '태이',
            createdAt: DateTime.utc(2026, 10, 10, 3),
          );

  MemberInfo member;

  /// GET me 실패. (401 만료·네트워크 등)
  DioException? fetchError;

  /// PATCH me 실패.
  DioException? updateError;
  Completer<void>? fetchGate;
  Completer<void>? updateGate;
  int fetchCount = 0;
  final updateCalls = <String>[];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCount++;
    await fetchGate?.future;
    if (fetchError != null) throw fetchError!;
    return member;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updateCalls.add(nickname);
    await updateGate?.future;
    if (updateError != null) throw updateError!;
    member = member.copyWith(nickname: nickname);
    return member;
  }
}

class FakeEmailPreferences implements EmailPreferences {
  String? saved;

  @override
  Future<String?> readSavedEmail() async => saved;

  @override
  Future<void> saveEmail(String email) async => saved = email.trim();

  @override
  Future<void> clearEmail() async => saved = null;
}

class FakeInstallMarker implements InstallMarker {
  FakeInstallMarker({this.initialized = true});

  bool initialized;

  @override
  Future<bool> isInitialized() async => initialized;

  @override
  Future<void> markInitialized() async => initialized = true;
}

/// 보호 요청 401. code는 AUTH401_2(없음)·_3(무효)·_4(만료).
DioException fakeSessionExpired([String code = 'AUTH401_4']) =>
    fakeMovieLogError(statusCode: 401, code: code, message: '토큰이 만료되었습니다.');

/// 상태 코드가 있는 실패(400·404 등) 또는 연결 실패(null)를 흉내 낸 DioException.
///
/// [code]·[message]를 주면 공통 실패 응답 body(`isSuccess/code/message/result`)를 담는다.
DioException fakeMovieLogError({
  int? statusCode,
  String path = '/v7',
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
