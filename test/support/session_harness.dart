import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/view_models/auth_view_model.dart';

import 'fake_movielog_services.dart';

/// 로그인한 [AuthViewModel]과 그 상태를 따라가는 [SessionGuard]를 한 번에 만든다.
///
/// 앱의 `AuthSessionBridge` Provider와 같은 연결이다. 테스트에서 "계정 전환"을 흉내 낼 때 쓴다.
class SessionHarness {
  SessionHarness._(this.storage, this.members, this.auth, this.bridge);

  final InMemoryTokenStorage storage;
  final FakeMemberApiService members;
  final AuthViewModel auth;
  final AuthSessionBridge bridge;

  SessionGuard get guard => bridge.guard;
  String get email => auth.member!.email;

  static Future<SessionHarness> signedIn({
    String email = 'a@movielog.dev',
    FakeAuthApiService? authApi,
  }) async {
    final storage = InMemoryTokenStorage('token-a');
    final members = FakeMemberApiService(
      member: MemberInfo(
        email: email,
        nickname: '계정A',
        createdAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final auth = AuthViewModel(
      authApi ?? FakeAuthApiService(),
      members,
      storage,
    );
    final bridge = AuthSessionBridge(
      authSignals: auth,
      sessionVersion: () => auth.sessionVersion,
      verifiedEmail: () =>
          auth.status == AuthStatus.signedIn ? auth.member?.email : null,
    );
    await auth.restoreSession();
    return SessionHarness._(storage, members, auth, bridge);
  }

  /// 로그아웃한 뒤 다른 이메일의 계정으로 로그인한다.
  Future<void> switchAccountTo(String email) async {
    await auth.logout();
    members.member = MemberInfo(
      email: email,
      nickname: '계정B',
      createdAt: DateTime.utc(2026, 11, 2),
    );
    await auth.login(email, 'Umc1234!');
    await auth.loadMember();
  }

  void dispose() {
    bridge.dispose();
    auth.dispose();
  }
}
