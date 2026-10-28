/// 닉네임·이메일 중복 체크 응답. (`{ "available": true }`)
///
/// v6에서도 **성공** 응답은 공통 Wrapper(`result`) 없이 body가 곧 이 객체다.
/// 실패 응답만 `CommonResponse` 형식으로 감싸진다.
class CheckResult {
  const CheckResult({required this.available});

  /// 사용할 수 있으면 true, 이미 있으면 false.
  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}
