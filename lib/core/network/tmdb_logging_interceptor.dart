import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// TMDB Client를 지나는 모든 요청·응답·오류를 같은 형식으로 기록하는 Interceptor.
///
/// 화면마다 로그 코드를 따로 두지 않고 Client 한 곳에 등록하므로,
/// 어떤 화면에서 호출하든 로그 형식이 같다.
/// 로그를 화면에 표시하거나 파일로 저장하는 일은 하지 않는다. (기록만 담당)
class TmdbLoggingInterceptor extends Interceptor {
  /// 응답 Body가 너무 길면 콘솔이 잘려 읽기 어렵다. 앞부분만 남긴다.
  static const _maxBodyLength = 800;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[TMDB 요청] ${options.method} ${options.uri}');
    debugPrint('[TMDB 요청 Header] ${maskHeaders(options.headers)}');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[TMDB 요청 Query] ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[TMDB 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    debugPrint('[TMDB 응답 Body] ${_shorten('${response.data}')}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[TMDB 오류] ${err.requestOptions.method} ${err.requestOptions.uri}',
    );
    debugPrint('[TMDB 오류 Header] ${maskHeaders(err.requestOptions.headers)}');
    debugPrint(
      '[TMDB 오류 내용] ${err.type.name} / status ${err.response?.statusCode} / ${err.message}',
    );
    if (err.response?.data != null) {
      debugPrint('[TMDB 오류 Body] ${_shorten('${err.response?.data}')}');
    }
    handler.next(err);
  }

  /// Authorization 값은 원문 대신 `Bearer ***`로 바꾼 복사본을 돌려준다.
  ///
  /// 원본 Map을 고치면 실제 요청 Header까지 바뀌므로 반드시 복사본을 만든다.
  @visibleForTesting
  static Map<String, dynamic> maskHeaders(Map<String, dynamic> headers) {
    final masked = Map<String, dynamic>.from(headers);
    for (final key in masked.keys.toList()) {
      if (key.toLowerCase() == 'authorization') {
        masked[key] = 'Bearer ***';
      }
    }
    return masked;
  }

  static String _shorten(String text) => text.length <= _maxBodyLength
      ? text
      : '${text.substring(0, _maxBodyLength)}… (${text.length}자 중 일부)';
}
