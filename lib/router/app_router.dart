import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/session/session_guard.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/member_info.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../screens/debug/button_width_demo_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/movie_search_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/splash_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/paged_movies_view_model.dart';
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
/// │  /movies             영화 목록 (더 보기, 9주차)
/// │    /movies/search    영화 검색 (root Navigator, 9주차 — 정적 경로가 :movieId보다 먼저)
/// │  /my                 마이페이지 (앱바 로그아웃)
/// │    /my/ratings       이번 세션에서 등록한 평점 (root Navigator → NavigationBar 없음)
/// │    /my/favorites     내 즐겨찾기 (root Navigator, 9주차)
/// │    /my/profile/edit  프로필 수정 (root Navigator, 8주차)
/// └
/// /movies/:movieId       영화 상세 (Shell 밖, 평점 등록·즐겨찾기)
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
                  ChangeNotifierProvider<PagedMoviesViewModel>(
                    create: (context) =>
                        PagedMoviesViewModel(
                            tmdbApi: context.read<TmdbMovieService>(),
                          )
                          ..loadGenres()
                          ..loadInitial(),
                    child: const MovieListScreen(),
                  ),
              routes: [
                // 정적인 search는 동적인 :movieId보다 **먼저** 등록한다. 순서가 바뀌면 search가 영화 ID로 해석된다.
                // 영화 목록과 별도의 PagedMoviesViewModel을 새로 만든다.
                GoRoute(
                  path: 'search', // 최종 경로: /movies/search
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) =>
                      ChangeNotifierProvider<PagedMoviesViewModel>(
                        create: (context) => PagedMoviesViewModel(
                          tmdbApi: context.read<TmdbMovieService>(),
                        ),
                        child: MovieSearchScreen(
                          onOpenMovie: (movie) async {
                            await context.push(
                              '/movies/${movie.id}',
                              extra: movie,
                            );
                          },
                        ),
                      ),
                ),
              ],
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
                  path: 'favorites', // 최종 경로: /my/favorites
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => _favoritesRoute(context),
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
                                  onPressed: () => auth.loadMember(force: true),
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
            final detail = MovieDetailLoader(
              // 같은 Route에서 id만 바뀌면 State가 재사용되므로 id를 Key로 준다.
              key: ValueKey(id),
              movieId: id,
              initialMovie: extra is TmdbMovieDto && extra.id == id
                  ? extra
                  : null,
            );
            return _withVerifiedSession(
              context,
              title: '영화 상세',
              builder: (member, guard) =>
                  ChangeNotifierProvider<FavoriteDetailViewModel>(
                    // 계정이나 세션이 바뀌면 key가 달라져 이전 계정의 ViewModel을 버리고 새로 만든다.
                    // 닉네임 수정·build 재실행으로는 key가 바뀌지 않는다.
                    key: ValueKey('${member.email}:${guard.generation}'),
                    create: (context) => FavoriteDetailViewModel(
                      movieId: id,
                      favoriteApi: context.read<FavoriteApiService>(),
                      sessionGuard: guard,
                      accountId: member.email,
                      auth: context.read<AuthViewModel>(),
                    ),
                    child: detail,
                  ),
            );
          },
        ),
      ],
    );
  }

  /// 내 정보([AuthViewModel.member])가 준비되고 [SessionGuard]의 현재 계정과 일치할 때만 [builder]를 그린다.
  ///
  /// 즐겨찾기는 JWT로 사용자를 구분하고, 화면 쪽은 email + 세션 번호로 "누구의 상태인지" 구분한다.
  /// 내 정보가 아직 없으면 로딩을, 불러오기에 실패했으면 "다시 시도"를 보여 준다.
  /// (CircularProgressIndicator만 계속 보여 주지 않는다)
  static Widget _withVerifiedSession(
    BuildContext context, {
    required String title,
    required Widget Function(MemberInfo member, SessionGuard guard) builder,
  }) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;
    final guard = context.read<SessionGuard>();
    if (member == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title), centerTitle: true),
        body: Center(
          child: auth.memberStatus == MemberLoadStatus.error
              ? MovieLogButton(
                  label: '내 정보 다시 조회',
                  width: 180,
                  onPressed: () => auth.loadMember(force: true),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    if (guard.accountId != member.email) {
      return Scaffold(
        appBar: AppBar(title: Text(title), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return builder(member, guard);
  }

  /// `/my/favorites`: 현재 세션의 [FavoritesViewModel]을 만들어 [FavoritesScreen]에 넘긴다.
  /// 즐겨찾기 API에는 memberId를 보내지 않는다. email은 화면 쪽 세션 구분에만 쓴다.
  static Widget _favoritesRoute(BuildContext context) {
    return _withVerifiedSession(
      context,
      title: '내 즐겨찾기',
      builder: (member, guard) => ChangeNotifierProvider<FavoritesViewModel>(
        key: ValueKey('${member.email}:${guard.generation}'),
        create: (context) => FavoritesViewModel(
          favoriteApi: context.read<FavoriteApiService>(),
          tmdbApi: context.read<TmdbMovieService>(),
          sessionGuard: guard,
          accountId: member.email,
          auth: context.read<AuthViewModel>(),
        ),
        child: FavoritesScreen(
          onOpenMovie: (movie) async {
            await context.push('/movies/${movie.id}', extra: movie);
          },
        ),
      ),
    );
  }

  /// 현재 경로로 NavigationBar의 선택 탭을 정한다.
  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
