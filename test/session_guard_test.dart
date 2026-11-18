// 세션 판정(SessionGuard·AuthSessionBridge)과 공용 유틸(mapBounded·SafeNotify) 테스트. (9주차)

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/core/utils/safe_notify.dart';

import 'support/session_harness.dart';

class _Notifier extends ChangeNotifier with SafeNotify {}

void main() {
  group('SessionGuard', () {
    test('세션을 시작하면 계정과 generation이 정해지고, 같은 값일 때만 현재 세션이다', () {
      final guard = SessionGuard();
      final generation = guard.startSession('a@x.com');

      expect(guard.isCurrent(generation, 'a@x.com'), isTrue);
      expect(guard.isCurrent(generation, 'b@x.com'), isFalse);
      expect(guard.isCurrent(generation - 1, 'a@x.com'), isFalse);
    });

    test('invalidate하면 이전 세션의 응답은 모두 현재가 아니다', () {
      final guard = SessionGuard();
      final old = guard.startSession('a@x.com');
      guard.invalidate();

      expect(guard.accountId, isNull);
      expect(guard.isCurrent(old, 'a@x.com'), isFalse);
    });

    test('같은 계정으로 다시 시작해도 새 세션이다 (토큰이 새로 발급됐으므로)', () {
      final guard = SessionGuard();
      final first = guard.startSession('a@x.com');
      final second = guard.startSession('a@x.com');

      expect(second, isNot(first));
      expect(guard.isCurrent(first, 'a@x.com'), isFalse);
    });
  });

  group('AuthSessionBridge', () {
    test('로그인하고 내 정보를 받으면 그 이메일이 현재 계정이 된다', () async {
      final session = await SessionHarness.signedIn();
      addTearDown(session.dispose);

      expect(session.guard.accountId, 'a@movielog.dev');
    });

    test('닉네임이 바뀌어도(같은 이메일·같은 세션) generation은 바뀌지 않는다', () async {
      final session = await SessionHarness.signedIn();
      addTearDown(session.dispose);
      final before = session.guard.generation;

      session.auth.updateMember(
        session.auth.member!.copyWith(nickname: '새 닉네임'),
      );

      expect(session.guard.generation, before);
    });

    test('로그아웃하면 계정이 비고, 다른 계정으로 로그인하면 새 generation이다', () async {
      final session = await SessionHarness.signedIn();
      addTearDown(session.dispose);
      final a = session.guard.generation;

      await session.auth.logout();
      expect(session.guard.accountId, isNull);
      expect(session.guard.isCurrent(a, 'a@movielog.dev'), isFalse);

      await session.switchAccountTo('b@movielog.dev');
      expect(session.guard.accountId, 'b@movielog.dev');
      expect(session.guard.isCurrent(a, 'a@movielog.dev'), isFalse);
    });

    test('같은 이메일로 다시 로그인해도 새 세션이다', () async {
      final session = await SessionHarness.signedIn();
      addTearDown(session.dispose);
      final first = session.guard.generation;

      await session.switchAccountTo('a@movielog.dev');

      expect(session.guard.accountId, 'a@movielog.dev');
      expect(session.guard.isCurrent(first, 'a@movielog.dev'), isFalse);
    });
  });

  group('mapBounded', () {
    test('결과는 입력과 같은 순서이고, 동시에 진행하는 요청은 제한을 넘지 않는다', () async {
      var running = 0;
      var maxRunning = 0;
      final result = await mapBounded<int, int>(
        List.generate(12, (i) => i),
        5,
        (value) async {
          running++;
          if (running > maxRunning) maxRunning = running;
          // 앞 값일수록 늦게 끝나게 해서 순서가 뒤집히는지 확인한다.
          await Future<void>.delayed(Duration(milliseconds: 12 - value));
          running--;
          return value * 10;
        },
      );

      expect(result, List.generate(12, (i) => i * 10));
      expect(maxRunning, lessThanOrEqualTo(5));
      expect(maxRunning, greaterThan(1));
    });

    test('빈 입력은 빈 목록, 0 이하의 동시성은 ArgumentError', () async {
      expect(await mapBounded<int, int>(const [], 5, (v) async => v), isEmpty);
      expect(
        () => mapBounded<int, int>([1], 0, (v) async => v),
        throwsArgumentError,
      );
    });
  });

  group('SafeNotify', () {
    test('dispose 뒤에는 notifyIfAlive가 아무 일도 하지 않는다', () {
      final notifier = _Notifier();
      var calls = 0;
      notifier.addListener(() => calls++);

      notifier.notifyIfAlive();
      expect(calls, 1);

      notifier.dispose();
      expect(notifier.isDisposed, isTrue);
      expect(notifier.notifyIfAlive, returnsNormally);
    });
  });
}
