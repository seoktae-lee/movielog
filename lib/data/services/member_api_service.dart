import 'package:dio/dio.dart';

import '../models/member_info.dart';

/// 내 정보 API. **보호용** Client(AuthInterceptor 등록)를 받는다.
///
/// path에 memberId가 없다. 서버가 Authorization의 토큰으로 "누구의 요청인지" 판단한다.
class MemberApiService {
  MemberApiService(this._authDio);

  final Dio _authDio;

  /// `GET /v7/members/me`. 앱 재시작 시 저장된 토큰이 아직 유효한지 확인하는 데도 쓴다.
  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get('/v7/members/me');
    return parseMemberInfo(response.data);
  }

  /// `PATCH /v7/members/me`. 수정 가능한 값은 닉네임뿐이고, 성공 result가 최신 내 정보다.
  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch(
      '/v7/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}
