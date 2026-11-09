import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/debug/button_width_demo_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/splash_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/session_rating_store.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/movielog_button.dart';

/// 인증 상태별 화면 규칙. Router의 redirect가 이 함수 하나만 부른다.
///
/// ```
/// initializing·retryRequired → /start (Splash) 유지
/// signedOut·authenticating   → 공개 화면(/login, /register)만, 나머지는 /login
/// signedIn                   → /start·/login·/register면 /home, 나머지는 그대로
/// ```
///
/// 상태만 읽고 판단한다. 여기서 API 호출 같은 비동기 작업을 하지 않는다.
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    AuthStatus.initializing ||
    AuthStatus.retryRequired => atStart ? null : '/start',
    AuthStatus.signedOut ||
    AuthStatus.authenticating => atPublic ? null : '/login',
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

/// 앱의 모든 Route를 한곳에서 관리하는 클래스.
///
/// ```
/// /start                 Splash (세션 확인 중 / 확인 실패 시 재시도)
/// /login                 로그인 (8주차)
/// /register              회원가입
/// ┌ ShellRoute (MainScreen + NavigationBar, 처음 열릴 때 GET me)
/// │  /home               홈
/// │  /movies             영화 목록
/// │  /my                 마이페이지 (앱바 로그아웃)
/// │    /my/ratings       이번 세션에서 등록한 평점 (root Navigator → NavigationBar 없음)
/// │    /my/profile/edit  프로필 수정 (root Navigator, 8주차)
/// └
/// /movies/:movieId       영화 상세 (Shell 밖, 평점 등록)
/// ```
///
/// 7주차까지는 `static final router` 하나였다. 8주차부터 redirect가 [AuthViewModel]을 알아야 하므로
/// 인스턴스를 받는 [createRouter]로 바꾸고, 앱이 살아 있는 동안 한 번만 만든다.
class AppRouter {
  AppRouter._();

  /// 앱 전체(root) Navigator를 가리키는 키.
  ///
  /// ShellRoute 안의 GoRoute에 parentNavigatorKey로 주면 Shell 바깥(NavigationBar 위)에 쌓인다.
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      // redirect는 기본적으로 "이동할 때"만 호출된다.
      // 인증 상태가 바뀔 때도 다시 검사하도록 AuthViewModel의 알림을 연결한다.
      refreshListenable: authViewModel,
      redirect: (context, state) =>
          authRedirect(authViewModel.status, state.uri.path),
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return SplashScreen(
              message: auth.message,
              onRetry: auth.status == AuthStatus.retryRequired
                  ? auth.restoreSession
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) {
            final extra = state.extra;
            return LoginScreen(initialEmail: extra is String ? extra : null);
          },
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => ChangeNotifierProvider<SignUpViewModel>(
            create: (context) => SignUpViewModel(context.read<SignUpService>()),
            child: const SignUpScreen(),
          ),
        ),
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
              builder: (context, state) =>
                  ChangeNotifierProvider<MovieHomeViewModel>(
                    create: (context) =>
                        MovieHomeViewModel(context.read<TmdbMovieService>())
                          ..loadPopular(),
                    child: const HomeScreen(),
                  ),
            ),
            GoRoute(
              path: '/movies',
              builder: (context, state) =>
                  ChangeNotifierProvider<MovieListViewModel>(
                    create: (context) =>
                        MovieListViewModel(context.read<TmdbMovieService>())
                          ..loadInitial(),
                    child: const MovieListScreen(),
                  ),
            ),
            GoRoute(
              path: '/my',
              builder: (context, state) => const MyPageScreen(),
              routes: [
                GoRoute(
                  path: 'ratings', // 최종 경로: /my/ratings
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      ChangeNotifierProvider<MyRatingsViewModel>(
                        // 7주차의 memberId 대신 로그인 세션과 세션 평점 보관함을 쓴다.
                        create: (context) => MyRatingsViewModel(
                          context.read<RatingApiService>(),
                          context.read<TmdbMovieService>(),
                          context.read<AuthViewModel>(),
                          context.read<SessionRatingStore>(),
                        )..load(),
                        child: const MyRatingsScreen(),
                      ),
                ),
                GoRoute(
                  path: 'profile/edit', // 최종 경로: /my/profile/edit
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    // 내 정보를 아직 못 받았으면 수정 화면을 열지 않고 로딩/재시도를 보여 준다.
                    if (auth.member == null) {
                      return Scaffold(
                        appBar: AppBar(
                          centerTitle: true,
                          title: const Text('프로필 수정'),
                        ),
                        body: Center(
                          child: auth.memberStatus == MemberLoadStatus.error
                              ? MovieLogButton(
                                  label: '다시 시도',
                                  onPressed: () =>
                                      auth.loadMember(force: true),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      );
                    }
                    return ChangeNotifierProvider<EditProfileViewModel>(
                      create: (context) => EditProfileViewModel(
                        context.read<MemberApiService>(),
                        auth,
                      ),
                      child: const EditProfileScreen(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // 디버그 전용: MovieLogButton 너비·상태 비교 (release에는 없음)
        if (kDebugMode)
          GoRoute(
            path: '/debug/buttons',
            builder: (context, state) => const ButtonWidthDemoScreen(),
          ),
        // 상세는 Shell 바깥에 두어 전체 화면으로 열리고, push로 왔으니 pop으로 돌아간다.
        GoRoute(
          path: '/movies/:movieId',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['movieId'] ?? '');
            if (id == null || id < 1) {
              return const MovieDetailInvalidId();
            }
            final extra = state.extra;
            return MovieDetailLoader(
              // 같은 Route에서 id만 바뀌면 State가 재사용되므로 id를 Key로 준다.
              key: ValueKey(id),
              movieId: id,
              initialMovie: extra is TmdbMovieDto && extra.id == id
                  ? extra
                  : null,
            );
          },
        ),
      ],
    );
  }

  /// 현재 경로로 NavigationBar의 선택 탭을 정한다.
  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
