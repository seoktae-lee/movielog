import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/tmdb_client.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// 앱 전체 설정을 담당하는 최상위 Widget.
class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key, this.movieService});

  /// 테스트에서 실제 TMDB 대신 fixture를 돌려주는 Service를 넣기 위한 통로.
  /// null이면 실제 TMDB Client로 만든 Service를 쓴다.
  final TmdbMovieService? movieService;

  @override
  Widget build(BuildContext context) {
    // 여러 화면(Route)이 함께 쓰는 객체는 MaterialApp.router 바깥, 즉 앱 최상단에 둔다.
    // GoRouter는 이동할 때마다 Route의 Widget Tree를 새로 만들기 때문에
    // 특정 화면 아래에 두면 다른 Route에서 context.read로 찾지 못한다.
    return MultiProvider(
      providers: [
        // Service는 상태가 없어서 홈·목록·상세 ViewModel이 인스턴스 하나를 함께 쓴다.
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
      ],
      // GoRouter를 쓰면 첫 화면과 화면 이동을 Router가 관리하므로
      // home 대신 routerConfig에 AppRouter를 넘긴다.
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
