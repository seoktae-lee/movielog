import 'package:dio/dio.dart';

/// 실패 응답 body에서 서버 오류 code를 꺼낸다. (`AUTH401_2`, `RATING409_1` 등)
///
/// 네트워크 실패처럼 body가 없거나 공통 형식이 아니면 null이다.
/// 화면 문구와 다음 행동(로그아웃할지, 입력칸에 표시할지)을 status가 아니라 이 code로 정한다.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

/// 실패 응답 body의 서버 message. 사용자에게 그대로 보여 줄 수 있는 문장이다.
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청에서 토큰이 없거나(`AUTH401_2`)·무효하거나(`AUTH401_3`)·만료된(`AUTH401_4`) 경우.
///
/// 로그인 실패 `AUTH401_1`은 여기에 넣지 않는다. 같은 401이지만 그건 로그인 Form의 입력 오류다.
const sessionExpiredCodes = {'AUTH401_2', 'AUTH401_3', 'AUTH401_4'};

/// 이 오류가 "현재 세션을 더 쓸 수 없다"는 뜻인지. 네트워크 실패·403·409는 false다.
bool isSessionExpiredError(Object error) =>
    error is DioException && sessionExpiredCodes.contains(apiErrorCode(error));
