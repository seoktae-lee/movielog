// 8주차 인증: AuthViewModel·AuthInterceptor·redirect·EditProfileViewModel 규칙을 확인한다.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/network/movie_log_client.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';

import 'support/fake_movielog_services.dart';

void main() {
  late FakeAuthApiService authApi;
  late FakeMemberApiService memberApi;
  late InMemoryTokenStorage storage;

  AuthViewModel create({String? token, FakeInstallMarker? marker}) {
    authApi = FakeAuthApiService();
    memberApi = FakeMemberApiService();
    storage = InMemoryTokenStorage(token);
    return AuthViewModel(authApi, memberApi, storage, installMarker: marker);
  }

  group('세션 복원 restoreSession', () {
    test('토큰이 없으면 GET me 없이 signedOut', () async {
      final auth = create();
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedOut);
      expect(memberApi.fetchCount, 0);
    });

    test('토큰이 있어도 GET me 성공 뒤에만 signedIn', () async {
      final auth = create(token: 'saved');
      memberApi.fetchGate = Completer<void>();

      final restoring = auth.restoreSession();
      await pumpEventQueue();
      expect(auth.status, AuthStatus.initializing); // 아직 확정하지 않는다.

      memberApi.fetchGate!.complete();
      await restoring;
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '태이');
    });

    test('만료 토큰(AUTH401_4)이면 토큰을 지우고 signedOut + 만료 표시', () async {
      final auth = create(token: 'expired');
      memberApi.fetchError = fakeSessionExpired();
      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });

    test('네트워크 실패면 토큰을 지우지 않고 retryRequired', () async {
      final auth = create(token: 'saved');
      memberApi.fetchError = fakeMovieLogError(); // 연결 실패
      await auth.restoreSession();

      expect(auth.status, AuthStatus.retryRequired);
      expect(storage.token, 'saved');

      memberApi.fetchError = null;
      await auth.restoreSession();
      expect(auth.status, AuthStatus.signedIn);
    });

    test('저장소 읽기 실패는 서버 401과 다른 문구로 retryRequired', () async {
      final auth = create(token: 'saved');
      storage.failRead = true;
      await auth.restoreSession();
      expect(auth.status, AuthStatus.retryRequired);
      expect(auth.message, contains('저장소'));
    });

    test('(심화) 최초 설치 flag가 없으면 남은 토큰을 지우고 flag를 기록한다', () async {
      final marker = FakeInstallMarker(initialized: false);
      final auth = create(token: 'left-from-old-install', marker: marker);
      await auth.restoreSession();

      expect(storage.token, isNull);
      expect(marker.initialized, isTrue);
      expect(auth.status, AuthStatus.signedOut);
      expect(memberApi.fetchCount, 0);
    });
  });

  group('로그인 login', () {
    test('성공: 토큰 저장 → signedIn. GET me는 MainScreen이 부른다', () async {
      final auth = create();
      await auth.restoreSession();
      await auth.login('taei@movielog.dev', 'Umc1234!');

      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, 'token-1');
      expect(memberApi.fetchCount, 0);
      expect(auth.sessionExpired, isFalse);
    });

    test('AUTH401_1은 Form 문구만, 만료 표시를 켜지 않는다', () async {
      final auth = create();
      await auth.restoreSession();
      await auth.login('taei@movielog.dev', 'wrong');

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(auth.sessionExpired, isFalse);
      expect(storage.deleteCount, 0);
    });

    test('통신 실패·저장 실패는 서로 다른 문구', () async {
      final auth = create();
      await auth.restoreSession();
      authApi.error = fakeMovieLogError();
      await auth.login('a@b.com', 'Umc1234!');
      expect(auth.message, contains('로그인 요청에 실패'));

      authApi.error = null;
      storage.failWrite = true;
      await auth.login('a@b.com', 'Umc1234!');
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, contains('안전하게 저장하지 못했어요'));
    });

    test('로그인 중 중복 탭은 요청을 한 번만 보낸다', () async {
      final auth = create();
      await auth.restoreSession();
      authApi.gate = Completer<void>();
      final first = auth.login('a@b.com', 'Umc1234!');
      await auth.login('a@b.com', 'Umc1234!');
      authApi.gate!.complete();
      await first;
      expect(authApi.calls, hasLength(1));
    });
  });

  group('내 정보·만료·로그아웃', () {
    Future<AuthViewModel> signedIn() async {
      final auth = create();
      await auth.restoreSession();
      await auth.login('taei@movielog.dev', 'Umc1234!');
      return auth;
    }

    test('loadMember: 네트워크 실패는 로그아웃이 아니라 error', () async {
      final auth = await signedIn();
      memberApi.fetchError = fakeMovieLogError();
      await auth.loadMember();
      expect(auth.memberStatus, MemberLoadStatus.error);
      expect(auth.status, AuthStatus.signedIn);

      memberApi.fetchError = null;
      await auth.loadMember(force: true);
      expect(auth.memberStatus, MemberLoadStatus.success);
    });

    test('동시에 401 두 개가 와도 세션 정리는 한 번, 이전 세션의 401은 새 세션을 지우지 않는다', () async {
      final auth = await signedIn();
      final oldVersion = auth.sessionVersion;

      await Future.wait([
        auth.expireSession(oldVersion),
        auth.expireSession(oldVersion),
      ]);
      expect(storage.deleteCount, 1);

      auth.consumeSessionExpired();
      await auth.login('taei@movielog.dev', 'Umc1234!');
      await auth.expireSession(oldVersion); // 늦게 도착한 이전 세션 401
      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, 'token-1');
    });

    test('직접 로그아웃은 만료 Snackbar를 켜지 않고 토큰·member를 지운다', () async {
      final auth = await signedIn();
      await auth.loadMember();
      await auth.logout();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.member, isNull);
      expect(storage.token, isNull);
      expect(auth.sessionExpired, isFalse);
    });

    test('로그아웃 뒤 늦게 도착한 GET me는 무시한다', () async {
      final auth = await signedIn();
      memberApi.fetchGate = Completer<void>();
      final loading = auth.loadMember();
      await auth.logout();
      memberApi.fetchGate!.complete();
      await loading;
      expect(auth.member, isNull);
    });
  });

  group('프로필 수정 EditProfileViewModel', () {
    Future<(AuthViewModel, EditProfileViewModel)> setup() async {
      final auth = create(token: 'saved');
      await auth.restoreSession();
      return (auth, EditProfileViewModel(memberApi, auth));
    }

    test('2~12자 검증은 요청 전에 막는다', () async {
      final (_, vm) = await setup();
      expect(await vm.save('a'), isFalse);
      expect(vm.nicknameError, contains('2~12자'));
      expect(memberApi.updateCalls, isEmpty);
    });

    test('현재 닉네임과 같으면 요청 없이 성공', () async {
      final (_, vm) = await setup();
      expect(await vm.save(' 태이 '), isTrue);
      expect(memberApi.updateCalls, isEmpty);
    });

    test('성공하면 AuthViewModel.member를 교체한다', () async {
      final (auth, vm) = await setup();
      expect(await vm.save('새닉네임'), isTrue);
      expect(auth.member?.nickname, '새닉네임');
    });

    test('MEMBER409_1은 필드 오류, 네트워크 실패는 Snackbar 문구이고 로그아웃하지 않는다', () async {
      final (auth, vm) = await setup();
      memberApi.updateError = fakeMovieLogError(
        statusCode: 409,
        code: 'MEMBER409_1',
      );
      expect(await vm.save('영화광'), isFalse);
      expect(vm.nicknameError, '이미 사용 중인 닉네임이에요.');

      memberApi.updateError = fakeMovieLogError();
      expect(await vm.save('다른닉'), isFalse);
      expect(vm.nicknameError, isNull);
      expect(vm.message, contains('네트워크'));
      expect(auth.status, AuthStatus.signedIn);
    });

    test('401이면 세션을 정리한다', () async {
      final (auth, vm) = await setup();
      memberApi.updateError = fakeSessionExpired('AUTH401_3');
      expect(await vm.save('다른닉'), isFalse);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
    });
  });

  group('AuthInterceptor', () {
    test('보호 경로에만 Bearer를 붙이고, 공개 경로·다른 host에는 붙이지 않는다', () async {
      final dio = createAuthMovieLogClient(InMemoryTokenStorage('jwt'));
      final seen = <String, Object?>{};
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            seen[options.uri.toString()] = options.headers['Authorization'];
            handler.resolve(Response(requestOptions: options, statusCode: 200));
          },
        ),
      );

      await dio.get('/v7/members/me');
      await dio.post('/v7/ratings');
      await dio.patch('/v7/ratings/3');
      await dio.get('/v7/members/1/ratings');
      await dio.post('/v7/auth/login');
      await dio.get('https://api.themoviedb.org/3/movie/550');

      expect(seen, {
        'https://workbook.devnoco.com/v7/members/me': 'Bearer jwt',
        'https://workbook.devnoco.com/v7/ratings': 'Bearer jwt',
        'https://workbook.devnoco.com/v7/ratings/3': 'Bearer jwt',
        'https://workbook.devnoco.com/v7/members/1/ratings': null,
        'https://workbook.devnoco.com/v7/auth/login': null,
        'https://api.themoviedb.org/3/movie/550': null,
      });
    });

    test('저장소 읽기 실패는 서버 401이 아니라 요청 실패(unknown)', () async {
      final storage = InMemoryTokenStorage('jwt')..failRead = true;
      final dio = createAuthMovieLogClient(storage);
      try {
        await dio.get('/v7/members/me');
        fail('reject되어야 한다');
      } on DioException catch (error) {
        expect(error.type, DioExceptionType.unknown);
        expect(error.response, isNull);
      }
      expect(AuthInterceptor.isProtected(Uri.parse('https://evil.com/v7/ratings')), isFalse);
    });
  });

  test('redirect 규칙: 상태별로 갈 수 있는 화면', () {
    expect(authRedirect(AuthStatus.initializing, '/home'), '/start');
    expect(authRedirect(AuthStatus.retryRequired, '/start'), isNull);
    expect(authRedirect(AuthStatus.signedOut, '/my'), '/login');
    expect(authRedirect(AuthStatus.signedOut, '/register'), isNull);
    expect(authRedirect(AuthStatus.authenticating, '/login'), isNull);
    expect(authRedirect(AuthStatus.signedIn, '/login'), '/home');
    expect(authRedirect(AuthStatus.signedIn, '/start'), '/home');
    expect(authRedirect(AuthStatus.signedIn, '/my/profile/edit'), isNull);
  });

  test('가입일은 기기 시간대 기준 "yyyy.MM.dd 가입"', () {
    final date = DateTime(2026, 10, 10, 12); // 로컬 정오 → 어느 시간대든 같은 날
    expect(formatJoinedDate(date.toUtc()), '2026.10.10 가입');
  });
}
