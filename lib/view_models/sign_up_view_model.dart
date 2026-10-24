import 'package:flutter/foundation.dart';

import '../data/services/movielog_member_service.dart';

enum DuplicateCheckStatus { unchecked, checking, available, taken, error }

/// 닉네임 또는 이메일 한 칸의 중복 확인 결과.
@immutable
class DuplicateCheck {
  const DuplicateCheck(this.status, {this.value, this.message});

  static const unchecked = DuplicateCheck(DuplicateCheckStatus.unchecked);

  final DuplicateCheckStatus status;

  /// 어떤 값으로 확인했는지. 입력이 바뀌면 이 값과 달라지므로 결과를 버린다.
  final String? value;
  final String? message;
}

/// 회원가입 화면 전용 ViewModel. 닉네임·이메일 중복 확인 상태를 가진다.
///
/// 가입 API는 6주차에 만든다. 이번 주에는 "가입하기 전에 쓸 수 있는 값인지"만 서버에 묻는다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service);

  final MovieLogMemberService _service;

  DuplicateCheck nickname = DuplicateCheck.unchecked;
  DuplicateCheck email = DuplicateCheck.unchecked;

  bool _disposed = false;

  bool get isChecking =>
      nickname.status == DuplicateCheckStatus.checking ||
      email.status == DuplicateCheckStatus.checking;

  Future<DuplicateCheck> checkNickname(String value) async {
    nickname = await _check(
      value,
      onStart: (checking) => nickname = checking,
      request: _service.checkNickname,
      takenMessage: '이미 사용 중인 닉네임이에요.',
      availableMessage: '사용할 수 있는 닉네임이에요.',
    );
    _notify();
    return nickname;
  }

  Future<DuplicateCheck> checkEmail(String value) async {
    email = await _check(
      value,
      onStart: (checking) => email = checking,
      request: _service.checkEmail,
      takenMessage: '이미 가입된 이메일이에요.',
      availableMessage: '사용할 수 있는 이메일이에요.',
    );
    _notify();
    return email;
  }

  /// 입력이 바뀌면 이전 확인 결과는 더 이상 믿을 수 없다.
  void nicknameChanged(String value) {
    if (nickname.status != DuplicateCheckStatus.unchecked &&
        nickname.value != value.trim()) {
      nickname = DuplicateCheck.unchecked;
      _notify();
    }
  }

  void emailChanged(String value) {
    if (email.status != DuplicateCheckStatus.unchecked &&
        email.value != value.trim()) {
      email = DuplicateCheck.unchecked;
      _notify();
    }
  }

  Future<DuplicateCheck> _check(
    String raw, {
    required void Function(DuplicateCheck checking) onStart,
    required Future<bool> Function(String value) request,
    required String takenMessage,
    required String availableMessage,
  }) async {
    final value = raw.trim();
    onStart(DuplicateCheck(DuplicateCheckStatus.checking, value: value));
    _notify();

    try {
      final available = await request(value);
      return available
          ? DuplicateCheck(
              DuplicateCheckStatus.available,
              value: value,
              message: availableMessage,
            )
          : DuplicateCheck(
              DuplicateCheckStatus.taken,
              value: value,
              message: takenMessage,
            );
    } on MovieLogApiException catch (error) {
      // 400(형식 오류)이면 서버가 준 문구, 연결 실패면 연결 안내를 그대로 보여 준다.
      return DuplicateCheck(
        DuplicateCheckStatus.error,
        value: value,
        message: error.message,
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
