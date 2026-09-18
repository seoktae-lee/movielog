import 'package:go_router/go_router.dart';

import '../sign_up_screen.dart';
import '../start_screen.dart';

/// 앱의 모든 Route를 한곳에서 관리하는 클래스.
///
/// 새 화면이 생기면 MaterialApp이 아니라 여기 [routes]에 GoRoute를 추가한다.
class AppRouter {
  // private 생성자: 외부에서 AppRouter()로 객체를 만들지 못하게 막는다.
  AppRouter._();

  // 앱 전체에서 라우터는 하나만 쓰므로 static final로 둔다.
  static final router = GoRouter(
    // 앱을 켰을 때 처음 보여줄 경로
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const SignUpScreen(),
      ),
    ],
  );
}
