import 'package:go_router/go_router.dart';

import '../home_screen.dart';
import '../main_screen.dart';
import '../movie_detail_screen.dart';
import '../movie_list_screen.dart';
import '../my_page_screen.dart';
import '../sign_up_screen.dart';
import '../start_screen.dart';

/// 앱의 모든 Route를 한곳에서 관리하는 클래스.
///
/// 새 화면이 생기면 MaterialApp이 아니라 여기 [routes]에 GoRoute를 추가한다.
///
/// ```
/// /start                 시작
/// /register              회원가입
/// ┌ ShellRoute (MainScreen + NavigationBar)
/// │  /home               홈
/// │  /movies?genre=..    영화 목록 (Query Parameter로 장르 필터)
/// │  /my                 마이페이지
/// └
/// /movies/:movieId       영화 상세 (Path Parameter, Shell 밖이라 NavigationBar 없음)
/// ```
class AppRouter {
  // private 생성자: 외부에서 AppRouter()로 객체를 만들지 못하게 막는다.
  AppRouter._();

  // 앱 전체에서 라우터는 하나만 쓰므로 static final로 둔다.
  static final router = GoRouter(
    // 앱을 켰을 때 처음 보여줄 경로
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const SignUpScreen(),
      ),
      // 탭 세 화면은 MainScreen이라는 껍데기(Shell) 안에서 body만 바꿔 끼운다.
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(
            // Query가 붙어도(/movies?genre=..) path만 보므로 탭 계산이 흔들리지 않는다.
            currentIndex: indexFromLocation(state.uri.path),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) => MovieListScreen(
              selectedGenres: _genresFromQuery(
                state.uri.queryParameters['genre'],
              ),
            ),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPageScreen(),
          ),
        ],
      ),
      // 상세는 Shell 바깥에 두어 전체 화면으로 열리고, push로 왔으니 pop으로 돌아간다.
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) => MovieDetailScreen(
          // ':movieId' 이름과 pathParameters의 Key가 같아야 한다. 숫자가 아니면 null.
          movieId: int.tryParse(state.pathParameters['movieId'] ?? ''),
        ),
      ),
    ],
  );

  /// 현재 경로로 NavigationBar의 선택 탭을 정한다.
  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }

  /// `genre=드라마,SF` 형태의 Query 값을 장르 집합으로 바꾼다. 없으면 빈 집합(전체).
  static Set<String> _genresFromQuery(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    return raw.split(',').where((genre) => genre.isNotEmpty).toSet();
  }
}
