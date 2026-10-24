import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/movie_log_app.dart';
import 'core/config/tmdb_config.dart';
import 'practice/dart_practice.dart';

Future<void> main() async {
  // runApp 전에 asset(.env)을 읽으려면 Flutter 엔진과 먼저 연결해야 한다.
  WidgetsFlutterBinding.ensureInitialized();

  // 로드가 끝나기 전에 값을 읽으면 비어 있으므로 반드시 await한다.
  await dotenv.load(fileName: '.env');

  if (kDebugMode) {
    // Mission 2의 Dart 문법 연습 결과는 디버그 모드에서 콘솔로 확인한다.
    runDartPractice();

    // Token 원문은 출력하지 않고, 채워져 있는지만 알린다.
    if (!TmdbConfig.hasAccessToken) {
      debugPrint(
        '[TMDB 설정] ${TmdbConfig.accessTokenKey}가 비어 있어요. '
        '.env.example을 복사해 .env를 만들고 값을 넣어 주세요.',
      );
    }
  }

  runApp(const MovieLogApp());
}
