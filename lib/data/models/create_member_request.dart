/// 회원가입 요청 Body. (`POST /v6/members`)
///
/// [toJson]은 Dart 객체 → 요청 JSON 방향이다.
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  /// 이메일·닉네임은 앞뒤 공백을 지운다.
  /// 비밀번호는 입력한 문자 자체가 의미 있으므로 trim하지 않는다. (공백 규칙은 Form validator가 맡는다)
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };

  /// 로그·디버그 출력에 비밀번호가 남지 않게 한다.
  @override
  String toString() =>
      'CreateMemberRequest(email: ${email.trim()}, nickname: ${nickname.trim()}, password: ***)';
}
