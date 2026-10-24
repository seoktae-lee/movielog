/// 닉네임·이메일 중복 체크 응답. (`{ "available": true }`)
///
/// v5는 공통 Wrapper(`result`)가 없어서 응답 body가 곧 이 객체다.
/// 6주차 이후 Wrapper가 생기면 `json['result']`를 꺼낸 뒤 넘기게 된다.
class CheckResult {
  const CheckResult({required this.available});

  /// 사용할 수 있으면 true, 이미 있으면 false.
  final bool available;

  factory CheckResult.fromJson(Map<String, dynamic> json) {
    return CheckResult(available: json['available'] as bool);
  }
}
