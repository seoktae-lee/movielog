import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// 보호 API 요청에만 `Authorization: Bearer {MovieLog JWT}`를 붙이는 Interceptor.
///
/// 보호용 Client 하나에만 등록한다. 로그인·중복 확인용 공개 Client와 TMDB Client에는 등록하지 않는다.
/// Client를 잘못 고르더라도 host·path를 한 번 더 확인해, 다른 서버(TMDB·이미지 CDN)로 토큰이 새지 않게 한다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final TokenStorage _storage;

  static const _host = 'workbook.devnoco.com';

  /// 토큰이 필요한 경로: 내 정보(GET·PATCH)와 평점 등록·수정·삭제.
  /// 유저별 평점 조회(`/v7/members/{id}/ratings`)는 공개 API라 여기에 없다.
  static bool isProtected(Uri uri) {
    final path = uri.path;
    return uri.host == _host &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!isProtected(options.uri)) {
      handler.next(options);
      return;
    }
    // 이전 요청에서 남은 토큰을 재사용하지 않도록 매번 지우고 저장소에서 다시 읽는다.
    options.headers.remove('Authorization');
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      // 토큰이 없으면 Header 없이 보낸다. 서버가 AUTH401_2로 답하고 세션 정리로 이어진다.
      handler.next(options);
    } catch (_) {
      // 서버 401과 기기 저장소 실패는 다른 오류다. 저장소 실패로 로그아웃시키지 않는다.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}
