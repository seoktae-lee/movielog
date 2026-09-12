import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'movie_log_app.dart';
import 'practice/dart_practice.dart';

void main() {
  // Mission 2의 Dart 문법 연습 결과는 디버그 모드에서 콘솔로 확인한다.
  if (kDebugMode) {
    runDartPractice();
  }

  runApp(const MovieLogApp());
}
