import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

/// 회원가입 화면이 쓰는 MovieLog API Service. (6주차 MemberCheckService에서 이름을 바꿨다)
///
/// 요청을 보내고 응답을 모델로 바꾸는 일만 한다. 결과를 저장하지 않는다(stateless).
/// 통신이 실패하면 [DioException]을 그대로 던지고, 문구는 ViewModel이 정한다.
class SignUpService {
  SignUpService(this._dio);

  final Dio _dio;

  /// 닉네임을 쓸 수 있으면 true. (`GET /v7/members/nickname/{nickname}`)
  ///
  /// 성공 응답은 v5처럼 `{ "available": true }` 직접 객체다. 실패만 공통 형식으로 감싸진다.
  Future<bool> checkNickname(String nickname) async {
    // 한글·공백·특수문자가 경로에 그대로 들어가지 않도록 인코딩한다.
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v7/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// 이메일을 쓸 수 있으면 true. (`GET /v7/members/email/{email}`)
  Future<bool> checkEmail(String email) async {
    // `@`도 경로에서는 `%40`으로 바꿔 보낸다.
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v7/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  /// 회원가입. (`POST /v7/members`, 성공 201 + `CommonResponse<SignUpResult>`)
  ///
  /// 중복 확인을 통과했어도 그 사이 다른 사람이 같은 값을 등록할 수 있다.
  /// 그래서 여기서 오는 409가 "최종" 중복 결과다.
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v7/members', data: request.toJson());

    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

/// 회원가입 실패(400·409)를 화면 문구로 바꾼다.
///
/// 두 오류 모두 서버 message가 이미 사용자에게 보여줄 수 있는 문장이라 그대로 쓴다.
/// (400 "비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다." /
///  409 "이미 사용 중인 이메일입니다." — 서버는 이메일을 먼저 검사한다)
String writeSignUpErrorMessage(DioException error) {
  return tryParseCommonError(error.response?.data)?.message ??
      '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
