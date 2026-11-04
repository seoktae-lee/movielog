import 'package:flutter/foundation.dart';

/// 학습용 "현재 회원" 상태. 회원가입 결과의 memberId를 보관한다.
///
/// 6주차에는 memberId 1을 상수로 썼다. 7주차에 새로 가입한 회원이 1을 계속 쓰면
/// **다른 회원의 path로 요청**하게 되므로, 가입 결과를 앱 최상단에 두고
/// 영화 상세·마이페이지 Route가 같은 값을 읽는다.
///
/// 메모리에만 있으므로 앱을 재시작하면 사라진다.
/// **memberId만 알고 있다는 사실은 인증이 아니다.** JWT 주차에는 보호 요청에서
/// memberId path를 없애고 서버가 토큰으로 현재 회원을 식별한다.
class LearningMemberSession extends ChangeNotifier {
  LearningMemberSession({this.memberId});

  int? memberId;

  void setMemberId(int id) {
    memberId = id;
    notifyListeners();
  }

  void clear() {
    memberId = null;
    notifyListeners();
  }
}

/// 디버그 캡처용: 회원가입을 거치지 않고 이미 만든 학습용 회원으로 시작한다.
/// (`--dart-define=LEARNING_MEMBER_ID=42`, release 빌드에서는 항상 null)
int? debugInitialMemberId() {
  const id = int.fromEnvironment('LEARNING_MEMBER_ID');
  return kDebugMode && id > 0 ? id : null;
}
