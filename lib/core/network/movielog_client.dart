import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/movielog_api_config.dart';
import 'tmdb_logging_interceptor.dart';

/// MovieLog 자체 백엔드 전용 Dio Client.
///
/// TMDB Client와 분리한다. 주소도 다르고, 인증 방식도 다르다.
/// (TMDB는 Bearer Token, 자체 API는 7주차부터 로그인 JWT)
/// TMDB Token이 우리 서버로 새어 나가지 않도록 Header를 공유하지 않는다.
Dio createMovieLogClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: MovieLogApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'accept': 'application/json'},
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(ApiLoggingInterceptor('MovieLog'));
  }

  return dio;
}
