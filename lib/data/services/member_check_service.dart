import 'package:dio/dio.dart';

import '../models/check_result.dart';

/// 닉네임·이메일 중복 체크 API를 호출하는 Service.
///
/// 요청을 보내고 응답을 모델로 바꾸는 일만 한다. 결과를 저장하지 않는다(stateless).
/// 통신이 실패하면 [DioException]을 그대로 던지고, 문구는 ViewModel이 정한다.
class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

  /// 닉네임을 쓸 수 있으면 true. (`GET /v5/members/nickname/{nickname}`)
  Future<bool> checkNickname(String nickname) async {
    // 한글·공백·특수문자가 경로에 그대로 들어가지 않도록 인코딩한다.
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v5/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// 이메일을 쓸 수 있으면 true. (`GET /v5/members/email/{email}`)
  Future<bool> checkEmail(String email) async {
    // `@`도 경로에서는 `%40`으로 바꿔 보낸다.
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v5/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }
}
