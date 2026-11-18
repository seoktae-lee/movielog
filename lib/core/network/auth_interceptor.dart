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

  static final _favoriteByMovie = RegExp(r'^/v8/favorites/[1-9]\d*$');

  /// 토큰이 필요한 요청인지. (9주차: 즐겨찾기·영화 기록 추가)
  ///
  /// - 8주차 그대로: 내 정보(GET·PATCH), 평점 등록·수정·삭제
  /// - 즐겨찾기: 등록(POST)·목록(GET) `/v8/favorites`, 여부 조회(GET)·해제(DELETE) `/v8/favorites/{movieId}`
  /// - 영화 기록 저장: POST `/v8/movie-records` (Challenge)
  ///
  /// 유저별 평점 조회(`/v8/members/{id}/ratings`)는 공개 API라 여기에 없다.
  /// 같은 경로라도 method가 다르면 보호 요청이 아니다. (예: `PUT /v8/favorites`)
  static bool isProtected(Uri uri, [String method = 'GET']) {
    if (uri.host != _host) return false;
    final path = uri.path;
    final m = method.toUpperCase();

    final w8Protected =
        path == '/v8/members/me' ||
        path == '/v8/ratings' ||
        path.startsWith('/v8/ratings/');
    final favorites =
        (path == '/v8/favorites' && (m == 'GET' || m == 'POST')) ||
        (_favoriteByMovie.hasMatch(path) && (m == 'GET' || m == 'DELETE'));
    final movieRecord = path == '/v8/movie-records' && m == 'POST';

    return w8Protected || favorites || movieRecord;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!isProtected(options.uri, options.method)) {
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
