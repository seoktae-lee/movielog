import 'package:flutter/material.dart';

import 'start_screen.dart';
import 'theme/app_theme.dart';

/// 앱 전체 설정을 담당하는 최상위 Widget.
class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      home: const StartScreen(),
    );
  }
}
