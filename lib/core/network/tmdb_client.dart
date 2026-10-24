import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/tmdb_config.dart';
import 'tmdb_logging_interceptor.dart';

/// TMDB 전용 Dio Client를 만든다.
///
/// MovieLog 자체 API(회원·평점)는 인증 방식이 달라서 Client를 따로 만든다.
/// 이 Client의 Authorization Header에는 TMDB Token만 들어간다.
Dio createTmdbClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization': 'Bearer ${TmdbConfig.accessToken}',
        'accept': 'application/json',
      },
    ),
  );

  // 로그는 개발 중 확인용이다. release 빌드(kDebugMode == false)에서는 등록하지 않는다.
  if (kDebugMode) {
    dio.interceptors.add(TmdbLoggingInterceptor());
  }

  return dio;
}
