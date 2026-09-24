import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// 앱 전체 설정을 담당하는 최상위 Widget.
class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GoRouter를 쓰면 첫 화면과 화면 이동을 Router가 관리하므로
    // home 대신 routerConfig에 AppRouter를 넘긴다.
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
