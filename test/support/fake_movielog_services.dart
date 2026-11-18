import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/core/storage/email_preferences.dart';
import 'package:movielog/core/storage/install_marker.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
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
  String path = '/v8',
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

FavoriteResponseDto fakeFavorite(int id, int movieId) =>
    FavoriteResponseDto.fromJson({
      'favoriteId': id,
      'movieId': movieId,
      'createdAt': '2026-11-17T10:00:00.000Z',
    });

/// 메모리 목록으로 `/v8/favorites` 네 개 API를 흉내 내는 Service.
///
/// 오류는 메서드별로 따로 줄 수 있고, [gate]로 응답을 붙잡아 "요청 중" 상태나 늦게 도착한 응답을 만든다.
class FakeFavoriteApiService implements FavoriteApiService {
  FakeFavoriteApiService({List<FavoriteResponseDto>? favorites})
    : favorites = List.of(favorites ?? const []);

  /// 서버에 있다고 가정한 즐겨찾기들. (최근 것이 위)
  List<FavoriteResponseDto> favorites;

  DioException? addError;
  DioException? deleteError;
  DioException? listError;
  DioException? checkError;

  /// 한 번만 실패하는 오류. 쓰고 나면 null로 돌아간다.
  DioException? nextListError;
  DioException? nextCheckError;

  /// 서버에서는 성공했지만 응답을 못 받은 상황(timeout)을 흉내 낸다. 쓰기 전에 실제로 반영한다.
  bool addSucceedsButTimesOut = false;

  Completer<void>? addGate;
  Completer<void>? deleteGate;
  Completer<void>? listGate;
  Completer<void>? checkGate;

  final addCalls = <int>[];
  final deleteCalls = <int>[];
  final checkCalls = <int>[];
  int listCalls = 0;

  bool isFavorite(int movieId) => favorites.any((f) => f.movieId == movieId);

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    addCalls.add(movieId);
    await addGate?.future;
    if (addSucceedsButTimesOut) {
      if (!isFavorite(movieId)) {
        favorites = [
          fakeFavorite(favorites.length + 100, movieId),
          ...favorites,
        ];
      }
      throw DioException(
        requestOptions: RequestOptions(path: '/v8/favorites'),
        type: DioExceptionType.receiveTimeout,
      );
    }
    if (addError != null) throw addError!;
    if (isFavorite(movieId)) {
      throw fakeMovieLogError(
        statusCode: 409,
        code: 'FAVORITE409_1',
        message: '이미 이 영화를 즐겨찾기하셨습니다.',
      );
    }
    final created = fakeFavorite(favorites.length + 1, movieId);
    favorites = [created, ...favorites];
    return created;
  }

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    listCalls++;
    await listGate?.future;
    final once = nextListError;
    if (once != null) {
      nextListError = null;
      throw once;
    }
    if (listError != null) throw listError!;
    return List.of(favorites);
  }

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    checkCalls.add(movieId);
    await checkGate?.future;
    final once = nextCheckError;
    if (once != null) {
      nextCheckError = null;
      throw once;
    }
    if (checkError != null) throw checkError!;
    return FavoriteCheckDto(movieId: movieId, isFavorite: isFavorite(movieId));
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    deleteCalls.add(movieId);
    await deleteGate?.future;
    if (deleteError != null) throw deleteError!;
    if (!isFavorite(movieId)) {
      throw fakeMovieLogError(
        statusCode: 404,
        code: 'FAVORITE404_1',
        message: '즐겨찾기를 찾을 수 없습니다.',
      );
    }
    favorites = [
      for (final f in favorites)
        if (f.movieId != movieId) f,
    ];
  }
}

/// `POST /v8/movie-records`를 흉내 낸다. 평점 목록·즐겨찾기 목록을 함께 바꾼다.
///
/// 서버처럼 한 트랜잭션이다: 이미 즐겨찾기한 영화에 addToFavorites=true면 평점도 저장하지 않는다.
class FakeMovieRecordApiService implements MovieRecordApiService {
  FakeMovieRecordApiService({this.ratings, this.favorites});

  final FakeRatingApiService? ratings;
  final FakeFavoriteApiService? favorites;

  DioException? error;
  Completer<void>? gate;
  final calls = <MovieRecordRequest>[];

  @override
  Future<MovieRecordResponse> saveMovieRecord(
    MovieRecordRequest request,
  ) async {
    calls.add(request);
    await gate?.future;
    if (error != null) throw error!;
    if (request.addToFavorites &&
        (favorites?.isFavorite(request.movieId) ?? false)) {
      throw fakeMovieLogError(
        statusCode: 409,
        code: 'FAVORITE409_1',
        message: '이미 이 영화를 즐겨찾기하셨습니다.',
      );
    }
    final rating = fakeRating(
      (ratings?.ratings.length ?? 0) + 1,
      request.movieId,
      request.score,
      request.comment,
    );
    ratings?.ratings = [rating, ...ratings!.ratings];
    FavoriteResponseDto? favorite;
    if (request.addToFavorites) {
      favorite = fakeFavorite(
        (favorites?.favorites.length ?? 0) + 1,
        request.movieId,
      );
      favorites?.favorites = [favorite, ...favorites!.favorites];
    }
    return MovieRecordResponse(rating: rating, favorite: favorite);
  }
}
