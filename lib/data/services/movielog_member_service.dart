import 'package:dio/dio.dart';

import '../models/member_rating_dto.dart';

/// MovieLog 자체 API가 실패했을 때 화면에 보여 줄 수 있는 예외.
class MovieLogApiException implements Exception {
  const MovieLogApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'MovieLogApiException($statusCode, $message)';
}

/// MovieLog 자체 백엔드의 회원·평점 API를 호출하는 Service.
///
/// TMDB Service와 마찬가지로 HTTP 요청과 DTO 변환만 하고, 결과를 저장하지 않는다.
class MovieLogMemberService {
  MovieLogMemberService(this._dio);

  final Dio _dio;

  /// 닉네임을 쓸 수 있으면 true. (`GET /members/nickname/{nickname}`)
  Future<bool> checkNickname(String nickname) =>
      _checkAvailable('/members/nickname/${Uri.encodeComponent(nickname)}');

  /// 이메일을 쓸 수 있으면 true. (`GET /members/email/{email}`)
  Future<bool> checkEmail(String email) =>
      _checkAvailable('/members/email/${Uri.encodeComponent(email)}');

  /// 회원이 남긴 평점, 최신순. (`GET /members/{memberId}/ratings`)
  Future<List<MemberRatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _send(
      () => _dio.get<List<dynamic>>('/members/$memberId/ratings'),
    );
    return (response.data ?? const [])
        .map((item) => MemberRatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> _checkAvailable(String path) async {
    final response = await _send(() => _dio.get<Map<String, dynamic>>(path));
    return response.data?['available'] as bool? ?? false;
  }

  /// 요청을 보내고, 실패하면 서버가 준 `message`를 담은 [MovieLogApiException]으로 바꾼다.
  ///
  /// 서버는 400·404에 `{"status": 400, "message": "닉네임은 2~12자여야 합니다."}`를 준다.
  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['message'] as String? : null;
      throw MovieLogApiException(
        serverMessage ?? _fallbackMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  String _fallbackMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return 'MovieLog 서버에 연결할 수 없어요. 서버가 켜져 있는지 확인해 주세요.';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'MovieLog 서버 응답이 너무 오래 걸려요.';
      default:
        return '요청을 처리하지 못했어요.';
    }
  }
}
