// 즐겨찾기 ViewModel 두 개(9주차): 상세 버튼 상태 · 내 즐겨찾기 목록.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';

import 'support/fake_movielog_services.dart';
import 'support/fake_tmdb_movie_service.dart';
import 'support/session_harness.dart';

void main() {
  late SessionHarness session;
  late FakeFavoriteApiService api;

  setUp(() async {
    session = await SessionHarness.signedIn();
    api = FakeFavoriteApiService();
  });
  tearDown(() => session.dispose());

  group('FavoriteDetailViewModel', () {
    FavoriteDetailViewModel create({int movieId = 550}) =>
        FavoriteDetailViewModel(
          movieId: movieId,
          favoriteApi: api,
          sessionGuard: session.guard,
          accountId: session.email,
          auth: session.auth,
        );

    test('load: 서버의 현재 여부를 반영하고 그 전에는 누를 수 없다', () async {
      api.favorites = [fakeFavorite(1, 550)];
      final vm = create();
      expect(vm.hasLoadedStatus, isFalse);

      await vm.load();

      expect(vm.isFavorite, isTrue);
      expect(vm.hasLoadedStatus, isTrue);
      expect(api.checkCalls, [550]);
    });

    test('등록: 서버 성공을 확인한 뒤에 북마크가 바뀌고, 요청 중에는 중복 탭을 막는다', () async {
      final vm = create();
      await vm.load();
      api.addGate = Completer<void>();

      final first = vm.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(vm.isSaving, isTrue);
      expect(vm.isFavorite, isFalse, reason: '서버 응답 전에는 바꾸지 않는다');
      await vm.toggle(); // 연타
      expect(api.addCalls, hasLength(1));

      api.addGate!.complete();
      await first;
      expect(vm.isFavorite, isTrue);
      expect(vm.isSaving, isFalse);
    });

    test('해제: DELETE는 200 + result null이므로 예외가 없으면 성공', () async {
      api.favorites = [fakeFavorite(1, 550)];
      final vm = create();
      await vm.load();

      await vm.toggle();

      expect(vm.isFavorite, isFalse);
      expect(api.deleteCalls, [550]);
      expect(vm.errorMessage, isNull);
    });

    test('등록 실패는 이전 아이콘 상태를 유지하고 문구를 남긴다', () async {
      api.addError = fakeMovieLogError(statusCode: 500);
      final vm = create();
      await vm.load();

      await vm.toggle();

      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, '즐겨찾기 등록에 실패했습니다.');
      expect(vm.isSaving, isFalse);
    });

    test('FAVORITE409_1: POST를 다시 보내지 않고 GET으로 서버 상태에 맞춘다', () async {
      final vm = create();
      await vm.load(); // 서버에는 없다고 알고 있었는데
      api.favorites = [fakeFavorite(9, 550)]; // 사이에 다른 기기에서 등록됨

      await vm.toggle();

      expect(api.addCalls, hasLength(1), reason: '추가 POST를 반복하지 않는다');
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
      expect(api.checkCalls, [550, 550]);
    });

    test('FAVORITE404_1: 이미 해제됐으면 GET으로 현재 여부를 확인해 맞춘다', () async {
      api.favorites = [fakeFavorite(1, 550)];
      final vm = create();
      await vm.load();
      api.favorites = []; // 다른 기기에서 먼저 해제함

      await vm.toggle();

      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, isNull);
      expect(api.deleteCalls, hasLength(1));
    });

    test('POST가 timeout이어도 자동으로 다시 보내지 않는다 (서버에는 성공했을 수 있다)', () async {
      api.addSucceedsButTimesOut = true;
      final vm = create();
      await vm.load();

      await vm.toggle();
      expect(api.addCalls, hasLength(1));
      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, isNotNull);

      // 사용자가 다시 누르면 POST가 409로 막히고, GET으로 서버 상태에 맞춰진다.
      api.addSucceedsButTimesOut = false;
      await vm.toggle();
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
    });

    test('첫 여부 조회가 실패하면 북마크를 켜지 못하고 다시 확인할 수 있다', () async {
      api.nextCheckError = fakeMovieLogError(statusCode: 500);
      final vm = create();

      await vm.load();
      expect(vm.hasLoadedStatus, isFalse);
      expect(vm.errorMessage, isNotNull);
      await vm.toggle();
      expect(api.addCalls, isEmpty, reason: '여부를 모르면 등록하지 않는다');

      await vm.load();
      expect(vm.hasLoadedStatus, isTrue);
    });

    test('응답이 늦게 도착했는데 그사이 계정이 바뀌었으면 반영하지 않는다', () async {
      api.favorites = [fakeFavorite(1, 550)];
      api.checkGate = Completer<void>();
      final vm = create();
      final loading = vm.load();
      await Future<void>.delayed(Duration.zero);

      await session.switchAccountTo('b@movielog.dev');
      api.checkGate!.complete();
      await loading;

      expect(vm.isFavorite, isFalse, reason: '이전 계정(A)의 응답을 버린다');
      expect(vm.hasLoadedStatus, isFalse);
    });

    test('세션 만료(AUTH401_4)면 세션을 한 번 정리한다. 403·네트워크 실패는 아니다', () async {
      final vm = create();
      await vm.load();

      api.addError = fakeMovieLogError(
        statusCode: 403,
        code: 'COMMON403',
        message: '권한 없음',
      );
      await vm.toggle();
      expect(session.auth.status, AuthStatus.signedIn);

      api.addError = fakeSessionExpired();
      await vm.toggle();
      expect(session.auth.status, AuthStatus.signedOut);
      expect(session.auth.sessionExpired, isTrue);
    });

    test('이전 계정에서 늦게 도착한 401이 지금 로그인한 계정을 로그아웃시키지 않는다', () async {
      api.checkGate = Completer<void>();
      api.nextCheckError = fakeSessionExpired();
      final vm = create();
      final loading = vm.load();
      await Future<void>.delayed(Duration.zero);

      await session.switchAccountTo('b@movielog.dev'); // 새 세션
      api.checkGate!.complete();
      await loading;

      expect(session.auth.status, AuthStatus.signedIn);
      expect(session.auth.member?.email, 'b@movielog.dev');
    });
  });

  group('FavoritesViewModel', () {
    late FakeTmdbMovieService tmdb;

    FavoritesViewModel create() => FavoritesViewModel(
      favoriteApi: api,
      tmdbApi: tmdb,
      sessionGuard: session.guard,
      accountId: session.email,
      auth: session.auth,
    );

    setUp(() => tmdb = FakeTmdbMovieService());

    test('목록을 받고 movieId로 TMDB 영화 정보를 합친다', () async {
      api.favorites = [fakeFavorite(2, 680), fakeFavorite(1, 550)];
      final vm = create();
      final seen = <LoadPhase>[];
      vm.addListener(() => seen.add(vm.phase));

      await vm.refresh();

      expect(seen.first, LoadPhase.loading);
      expect(vm.phase, LoadPhase.ready);
      expect(vm.items.map((i) => i.movie?.id), [680, 550]);
      expect(tmdb.detailCalls, containsAll([680, 550]));
    });

    test('즐겨찾기가 없으면 empty (오류가 아니다)', () async {
      final vm = create();
      await vm.refresh();
      expect(vm.phase, LoadPhase.empty);
    });

    test('목록 조회 전체 실패는 error', () async {
      api.listError = fakeMovieLogError(statusCode: 500);
      final vm = create();

      await vm.refresh();

      expect(vm.phase, LoadPhase.error);
      expect(vm.errorMessage, isNotNull);
    });

    test('영화 한 건의 정보만 실패하면 그 카드만 placeholder이고 나머지는 그대로', () async {
      api.favorites = [
        fakeFavorite(3, 1),
        fakeFavorite(2, 404),
        fakeFavorite(1, 3),
      ];
      tmdb.onDetail = (id) async {
        if (id == 404) throw fakeDioError(statusCode: 500);
        return FakeTmdbMovieService.detailFor(id);
      };
      final vm = create();

      await vm.refresh();

      expect(vm.phase, LoadPhase.ready, reason: '1건 실패로 목록 전체가 비지 않는다');
      expect(vm.items.map((i) => i.hasMovie), [true, false, true]);
      expect(vm.items[1].errorMessage, isNotNull);
    });

    test('실패한 카드만 다시 조회한다 (다른 카드의 TMDB 요청은 반복하지 않는다)', () async {
      api.favorites = [fakeFavorite(2, 404), fakeFavorite(1, 3)];
      var fail = true;
      tmdb.onDetail = (id) async {
        if (id == 404 && fail) throw fakeDioError(statusCode: 500);
        return FakeTmdbMovieService.detailFor(id);
      };
      final vm = create();
      await vm.refresh();
      tmdb.detailCalls.clear();

      fail = false;
      await vm.retryMovie(2);

      expect(tmdb.detailCalls, [404]);
      expect(vm.items.every((i) => i.hasMovie), isTrue);
    });

    test('상세에서 해제하고 돌아와 refresh하면 해제한 영화가 사라진다', () async {
      api.favorites = [fakeFavorite(2, 680), fakeFavorite(1, 550)];
      final vm = create();
      await vm.refresh();
      expect(vm.items, hasLength(2));

      await api.deleteFavorite(movieId: 550); // 상세에서 해제
      tmdb.detailCalls.clear();
      await vm.refresh();

      expect(vm.items.map((i) => i.movie?.id), [680]);
      expect(tmdb.detailCalls, isEmpty, reason: '이미 받은 영화 정보는 다시 조회하지 않는다');
    });

    test('이미 목록이 있을 때 갱신이 실패해도 목록은 그대로 둔다', () async {
      api.favorites = [fakeFavorite(1, 550)];
      final vm = create();
      await vm.refresh();

      api.listError = fakeMovieLogError(statusCode: 500);
      await vm.refresh();

      expect(vm.phase, LoadPhase.ready);
      expect(vm.items, hasLength(1));
      expect(vm.errorMessage, isNotNull);
    });

    test('TMDB 보충 요청은 한 번에 최대 5개만 보낸다', () async {
      api.favorites = [for (var i = 1; i <= 12; i++) fakeFavorite(i, 1000 + i)];
      var running = 0;
      var maxRunning = 0;
      tmdb.onDetail = (id) async {
        running++;
        if (running > maxRunning) maxRunning = running;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        running--;
        return FakeTmdbMovieService.detailFor(id);
      };
      final vm = create();

      await vm.refresh();

      expect(vm.items, hasLength(12));
      expect(maxRunning, lessThanOrEqualTo(5));
    });

    test('계정이 바뀌면 이전 계정의 응답은 반영하지 않는다', () async {
      api.favorites = [fakeFavorite(1, 550)];
      api.listGate = Completer<void>();
      final vm = create();
      final loading = vm.refresh();
      await Future<void>.delayed(Duration.zero);

      await session.switchAccountTo('b@movielog.dev');
      api.listGate!.complete();
      await loading;

      expect(vm.items, isEmpty, reason: 'A의 즐겨찾기가 B의 화면에 남지 않는다');
      expect(vm.phase, isNot(LoadPhase.ready));
    });

    test('세션 만료(AUTH401_3)면 세션을 정리하고 목록 오류 화면을 남기지 않는다', () async {
      api.listError = fakeSessionExpired('AUTH401_3');
      final vm = create();

      await vm.refresh();

      expect(session.auth.status, AuthStatus.signedOut);
      expect(vm.phase, isNot(LoadPhase.error));
    });
  });
}
