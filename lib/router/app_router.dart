import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

import '../screens/home_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_detail_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';

/// 앱의 모든 Route를 한곳에서 관리하는 클래스.
///
/// 새 화면이 생기면 MaterialApp이 아니라 여기 [routes]에 GoRoute를 추가한다.
///
/// ```
/// /start                 시작
/// /register              회원가입
/// ┌ ShellRoute (MainScreen + NavigationBar)
/// │  /home               홈
/// │  /movies             영화 목록 (장르 선택은 ViewModel이 관리)
/// │  /my                 마이페이지
/// └
/// /movies/:movieId       영화 상세 (TMDB id, Shell 밖이라 NavigationBar 없음)
/// ```
///
/// 화면별 ViewModel은 각 Route 안에서 [ChangeNotifierProvider]로 만든다.
/// 화면이 사라지면 ViewModel도 함께 dispose된다.
/// `create`는 Route가 처음 만들어질 때 한 번만 실행되므로 build마다 요청이 반복되지 않는다.
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
            builder: (context, state) =>
                ChangeNotifierProvider<MovieHomeViewModel>(
                  // ..(캐스케이드): 만든 ViewModel에 바로 loadPopular()를 호출하고
                  // 반환값이 아니라 ViewModel 자신을 create 결과로 넘긴다.
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
          ),
        ],
      ),
      // 상세는 Shell 바깥에 두어 전체 화면으로 열리고, push로 왔으니 pop으로 돌아간다.
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) {
          // ':movieId' 이름과 pathParameters의 Key가 같아야 한다. 숫자가 아니면 null.
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');

          return ChangeNotifierProvider<MovieDetailViewModel>(
            // 같은 Route에서 id만 바뀌면(/movies/1 → /movies/2) Element가 재사용되어
            // create가 다시 불리지 않는다. id를 Key로 주어 새 ViewModel을 만들게 한다.
            key: ValueKey(movieId),
            create: (context) => MovieDetailViewModel(
              context.read<TmdbMovieService>(),
              movieId: movieId,
              // 목록·홈에서 push할 때 넘긴 DTO. URL로 바로 들어오면 null이다.
              initialMovie: state.extra is TmdbMovieDto
                  ? state.extra as TmdbMovieDto
                  : null,
            )..load(),
            child: const MovieDetailScreen(),
          );
        },
      ),
    ],
  );

  /// 현재 경로로 NavigationBar의 선택 탭을 정한다.
  static int indexFromLocation(String path) {
    if (path.startsWith('/movies')) return 1;
    if (path.startsWith('/my')) return 2;
    return 0;
  }
}
