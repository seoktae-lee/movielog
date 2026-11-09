import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'tmdb_logging_interceptor.dart';

/// 워크북 참조 서버(MovieLog 자체 백엔드) Client.
///
/// TMDB Client와 절대 합치지 않는다. TMDB에는 TMDB Read Access Token만,
/// MovieLog 보호 요청에는 MovieLog JWT만 보낸다. 두 Authorization을 섞지 않는다.
///
/// 8주차부터 워크북 Client가 두 개다.
/// - 공개용 [createMovieLogClient]: 로그인·중복 확인·회원가입·유저별 평점 조회. Interceptor 없음
/// - 보호용 [createAuthMovieLogClient]: 내 정보·평점 등록/수정/삭제. [AuthInterceptor] 등록
BaseOptions _movieLogOptions() {
  return BaseOptions(
    baseUrl: 'https://workbook.devnoco.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );
}

/// 공개 요청용. 토큰을 붙이지 않는다.
Dio createMovieLogClient() {
  final dio = Dio(_movieLogOptions());
  if (kDebugMode) {
    dio.interceptors.add(ApiLoggingInterceptor('MovieLog'));
  }
  return dio;
}

/// 보호 요청용. 요청마다 저장소에서 토큰을 읽어 Bearer Header를 붙인다.
///
/// 로그 Interceptor를 AuthInterceptor **뒤에** 두면 Header가 붙은 뒤의 요청이 기록된다.
/// 로그는 Authorization 값을 `Bearer ***`로 가리므로 "붙었는지"만 확인할 수 있다.
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  if (kDebugMode) {
    dio.interceptors.add(ApiLoggingInterceptor('MovieLog 보호'));
  }
  return dio;
}
