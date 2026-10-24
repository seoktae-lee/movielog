import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/services/member_check_service.dart';

/// 중복 확인 한 칸의 상태. 버튼 활성화와 Form 에러가 모두 이 값에서 나온다.
enum CheckStatus {
  /// 아직 확인 안 함, 또는 입력이 바뀌어 이전 결과를 버림
  idle,

  /// 요청 중
  checking,

  /// 서버가 사용 가능하다고 응답함 (`available: true`)
  available,

  /// 서버가 이미 사용 중이라고 응답함 (`available: false`)
  duplicated,

  /// 통신 자체가 실패함 (DioException)
  error,
}

/// 회원가입 화면 전용 ViewModel. 닉네임·이메일 중복 확인 상태를 가진다.
///
/// 두 칸은 같은 화면에 있어도 상태를 절대 합치지 않는다.
/// 합치면 닉네임 결과가 이메일 칸에 영향을 준다. 그래서 칸마다 [DuplicateCheckField]를 하나씩 둔다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(MemberCheckService service)
    : _nickname = DuplicateCheckField(
        request: service.checkNickname,
        duplicatedMessage: '이미 사용 중인 닉네임입니다.',
      ),
      _email = DuplicateCheckField(
        request: service.checkEmail,
        duplicatedMessage: '이미 가입된 이메일입니다.',
      );

  final DuplicateCheckField _nickname;
  final DuplicateCheckField _email;
  bool _disposed = false;

  // ── 닉네임 ──
  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  void onNicknameChanged(String value) {
    _nickname.onChanged(value);
    _notify();
  }

  Future<void> checkNickname(String value) => _nickname.check(value, _notify);

  // ── 이메일 ──
  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  void onEmailChanged(String value) {
    _email.onChanged(value);
    _notify();
  }

  Future<void> checkEmail(String value) => _email.check(value, _notify);

  /// 두 칸 모두 서버 확인을 통과했는지. 가입하기 버튼 활성화 조건에 쓴다.
  bool get isAllAvailable =>
      nicknameCheckStatus == CheckStatus.available &&
      emailCheckStatus == CheckStatus.available;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // 기다리던 응답이 화면을 떠난 뒤 도착해도 무시되도록 버전을 올린다.
    _nickname.invalidate();
    _email.invalidate();
    super.dispose();
  }
}

/// 입력칸 하나(닉네임 또는 이메일)의 중복 확인 상태와 규칙.
///
/// - 입력이 바뀌면 이전 결과를 버린다(idle). 기다리던 응답도 버전으로 무시한다.
/// - 서버가 "중복"이라고 한 값은 [_duplicatedValue]에 기억한다.
///   같은 문자열을 다시 입력하면 서버에 묻지 않고 바로 duplicated로 되돌린다. (Challenge)
@visibleForTesting
class DuplicateCheckField {
  DuplicateCheckField({required this.request, required this.duplicatedMessage});

  final Future<bool> Function(String value) request;
  final String duplicatedMessage;

  static const errorMessage = '중복 확인에 실패했습니다. 다시 시도해 주세요.';

  CheckStatus status = CheckStatus.idle;
  String? errorText;

  /// 마지막으로 "중복"이었던 값. "마지막으로 확인한 값"과는 따로 기억한다.
  String? _duplicatedValue;

  /// 지금 입력칸에 들어 있는 값(trim). 응답이 왔을 때 아직 같은 값인지 비교한다.
  String _currentValue = '';

  /// 요청마다 1씩 올린다. 응답의 버전이 최신이 아니면 그 응답은 버린다.
  int _requestVersion = 0;

  /// 통신 중이 아니고, 이미 중복으로 확인된 값이 아닐 때만 누를 수 있다.
  bool get canCheck =>
      status != CheckStatus.checking && status != CheckStatus.duplicated;

  void onChanged(String value) {
    final trimmed = value.trim();
    _currentValue = trimmed;
    _requestVersion++; // 이전 요청의 응답을 무효화한다.

    if (_duplicatedValue != null && trimmed == _duplicatedValue) {
      // 방금 중복이었던 값으로 돌아왔다 → API 재호출 없이 즉시 에러 복원
      status = CheckStatus.duplicated;
      errorText = duplicatedMessage;
    } else {
      status = CheckStatus.idle;
      errorText = null;
    }
  }

  Future<void> check(String value, VoidCallback notify) async {
    final requested = value.trim();
    if (requested.isEmpty || !canCheck) return;
    // onChanged를 거치지 않고 값이 들어온 경우(초기값 등)에도 기준을 맞춘다.
    _currentValue = requested;

    final version = ++_requestVersion;
    status = CheckStatus.checking;
    errorText = null;
    notify();

    try {
      final available = await request(requested);
      if (!_isLatest(version, requested)) return;
      if (available) {
        status = CheckStatus.available;
        errorText = null;
      } else {
        status = CheckStatus.duplicated;
        errorText = duplicatedMessage;
        _duplicatedValue = requested;
      }
    } on DioException {
      if (!_isLatest(version, requested)) return;
      // 정상 응답의 available: false(중복)와 다른 상태·문구로 보여 준다.
      status = CheckStatus.error;
      errorText = errorMessage;
    }
    notify();
  }

  /// 화면을 떠날 때 기다리던 응답을 모두 무시하게 한다.
  void invalidate() => _requestVersion++;

  bool _isLatest(int version, String requested) =>
      version == _requestVersion && _currentValue == requested;
}
