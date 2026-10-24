import 'package:dio/dio.dart';

/// 요청 실패 원인을 사용자가 읽을 수 있는 문구로 바꾼다.
///
/// `DioException`의 원문 메시지·StackTrace는 로그(Interceptor)에만 남기고
/// 화면에는 이 문구만 보여 준다.
String tmdbErrorMessage(Object error, {required String fallback}) {
  if (error is! DioException) return fallback;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return '응답이 너무 오래 걸려요. 네트워크 상태를 확인해 주세요.';
    case DioExceptionType.connectionError:
      return '네트워크에 연결할 수 없어요. 연결을 확인해 주세요.';
    case DioExceptionType.badResponse:
      if (error.response?.statusCode == 401) {
        return 'TMDB 인증에 실패했어요. Token 설정을 확인해 주세요.';
      }
      return fallback;
    default:
      return fallback;
  }
}
