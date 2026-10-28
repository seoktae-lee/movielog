/// v6부터 쓰는 MovieLog 공통 응답 형식.
///
/// `{ isSuccess, code, message, result }` 네 필드로 성공 여부·처리 code·안내 문구·실제 데이터를 함께 받는다.
/// result는 API마다 담기는 값이 달라 제네릭 [T]로 두고, 값이 없거나 실패면 null이다.
///
/// - 회원가입·평점 등록·평점 수정 성공 응답
/// - v6 모든 API의 실패 응답
///
/// 은 이 형식이다. 중복 확인·평점 조회의 **성공** 응답은 v5처럼 직접 객체/배열이라 감싸지 않는다.
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code;
  final String message;
  final T? result;

  /// [parseResult]는 result 안의 값을 [T]로 바꾸는 함수다. result가 null이면 호출하지 않는다.
  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }
}

/// 실패 응답 body가 공통 형식이면 파싱하고, 아니면(네트워크 실패·HTML 등) null.
CommonResponse<Object?>? tryParseCommonError(Object? data) {
  if (data is! Map<String, dynamic>) return null;
  if (data['code'] is! String || data['message'] is! String) return null;
  return CommonResponse<Object?>.fromJson(data, (value) => value);
}
