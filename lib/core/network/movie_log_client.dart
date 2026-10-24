import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'tmdb_logging_interceptor.dart';

/// 워크북 참조 서버(MovieLog 자체 백엔드) 전용 Dio Client.
///
/// TMDB Client와 절대 합치지 않는다. 주소(baseUrl)도 다르고, 인증 방식도 다르다.
/// (TMDB는 Bearer Token, 자체 API는 7주차부터 로그인 JWT)
/// 하나로 합치면 TMDB Token이 우리 서버로 새어 나간다.
///
/// 6주차는 v5 명세를 쓴다. 경로 앞에 `/v5`를 붙이는 일은 Service가 한다.
Dio createMovieLogClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(ApiLoggingInterceptor('MovieLog'));
  }

  return dio;
}
