/// 회원가입 성공 응답의 result. (`CommonResponse<SignUpResult>`)
///
/// [fromJson]은 서버 응답 JSON → Dart 객체 방향이다. 비밀번호는 응답에 오지 않는다.
class SignUpResult {
  const SignUpResult({
    required this.memberId,
    required this.email,
    required this.nickname,
  });

  /// 이번 주차 평점 path(`/v6/members/{memberId}/...`)에 쓰는 학습용 식별자. 인증 수단이 아니다.
  final int memberId;
  final String email;
  final String nickname;

  factory SignUpResult.fromJson(Map<String, dynamic> json) {
    return SignUpResult(
      memberId: (json['memberId'] as num).toInt(),
      email: json['email'] as String,
      nickname: json['nickname'] as String,
    );
  }
}
