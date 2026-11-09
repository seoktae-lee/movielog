/// 로그인 요청 Body. (`POST /v7/auth/login`)
///
/// 비밀번호는 trim하지 않고 그대로 보낸다. 앱 어디에도 저장하지 않고, toString에도 넣지 않는다.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email.trim(), 'password': password};

  @override
  String toString() => 'LoginRequest(email: ${email.trim()}, password: ***)';
}

/// 로그인 성공 result. **memberId는 없다.** JWT payload에 있을 거라고 추정하지 않는다.
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      nickname: json['nickname'] as String,
      accessToken: json['accessToken'] as String,
    );
  }

  @override
  String toString() => 'LoginResult(nickname: $nickname, accessToken: ***)';
}
