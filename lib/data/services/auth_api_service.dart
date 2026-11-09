import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/login_models.dart';

/// 로그인 API. **공개용** Client를 받는다. (로그인 요청에는 아직 토큰이 없다)
class AuthApiService {
  AuthApiService(this._dio);

  final Dio _dio;

  /// `POST /v7/auth/login` → 200 + `CommonResponse<LoginResult>`.
  ///
  /// 이메일·비밀번호가 틀리면 401 `AUTH401_1`. 이 401은 세션 만료가 아니라 Form 오류다.
  Future<LoginResult> login(LoginRequest request) async {
    final response = await _dio.post('/v7/auth/login', data: request.toJson());
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('로그인 응답 형식이 올바르지 않습니다.');
    }
    final common = CommonResponse<LoginResult>.fromJson(
      data,
      (value) => LoginResult.fromJson(value as Map<String, dynamic>),
    );
    final result = common.result;
    if (result == null) throw StateError('로그인 result가 없습니다.');
    return result;
  }
}
