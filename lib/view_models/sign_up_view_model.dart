import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/create_member_request.dart';
import '../data/services/sign_up_service.dart';
import 'submit_status.dart';

export 'submit_status.dart';

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

/// 회원가입 화면 전용 ViewModel. 닉네임·이메일 중복 확인 상태와 가입 제출 상태를 가진다.
///
/// 두 칸은 같은 화면에 있어도 상태를 절대 합치지 않는다.
/// 합치면 닉네임 결과가 이메일 칸에 영향을 준다. 그래서 칸마다 [DuplicateCheckField]를 하나씩 둔다.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._service)
    : _nickname = DuplicateCheckField(
        request: _service.checkNickname,
        duplicatedMessage: '이미 사용 중인 닉네임입니다.',
      ),
      _email = DuplicateCheckField(
        request: _service.checkEmail,
        duplicatedMessage: '이미 가입된 이메일입니다.',
      );

  final SignUpService _service;
  final DuplicateCheckField _nickname;
  final DuplicateCheckField _email;
  bool _disposed = false;

  // ── 가입 제출 ──
  SubmitStatus submitStatus = SubmitStatus.idle;

  /// 가입 성공 응답의 result에서 읽은 실제 ID. 가입이 정말 끝났는지 확인하는 데만 쓴다. (v7 평점 요청에는 쓰지 않는다)
  int? createdMemberId;

  /// 서버가 비밀번호 형식을 거부했을 때(400) 비밀번호 칸 아래에 보여 줄 문구. (필드 단위 오류)
  String? passwordErrorText;

  /// 어느 칸에도 붙일 수 없는 오류(409 중복, 그 밖의 400·통신 실패). (화면 단위 오류 → Snackbar)
  String? snackbarMessage;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  // ── 닉네임 ──
  CheckStatus get nicknameCheckStatus => _nickname.status;
  String? get nicknameErrorText => _nickname.errorText;
  bool get canCheckNickname => _nickname.canCheck;

  void onNicknameChanged(String value) {
    _nickname.onChanged(value);
    _clearSubmitError();
    _notify();
  }

  Future<void> checkNickname(String value) => _nickname.check(value, _notify);

  // ── 이메일 ──
  CheckStatus get emailCheckStatus => _email.status;
  String? get emailErrorText => _email.errorText;
  bool get canCheckEmail => _email.canCheck;

  void onEmailChanged(String value) {
    _email.onChanged(value);
    _clearSubmitError();
    _notify();
  }

  Future<void> checkEmail(String value) => _email.check(value, _notify);

  /// 두 칸 모두 서버 확인을 통과했는지. 가입하기 버튼 활성화 조건에 쓴다.
  bool get isAllAvailable =>
      nicknameCheckStatus == CheckStatus.available &&
      emailCheckStatus == CheckStatus.available;

  // ── 비밀번호 ──
  /// 비밀번호를 다시 입력하면 서버가 거부했던 오류를 지운다.
  void onPasswordChanged() {
    if (passwordErrorText == null) return;
    passwordErrorText = null;
    _notify();
  }

  /// 회원가입 POST. 성공하면 [createdMemberId]가 채워지고 [submitStatus]가 success가 된다.
  ///
  /// - 400 + 비밀번호 문구 → [passwordErrorText] (비밀번호 칸 errorText)
  /// - 그 밖의 400, 409(최종 중복) → [snackbarMessage]
  /// - 201인데 result.memberId가 없음 → 가입 완료로 표시하지 않고 계약 오류로 처리
  Future<void> submit(CreateMemberRequest request) async {
    if (isSubmitting) return; // 연속 탭으로 같은 가입 요청이 두 번 가지 않게 한다.
    submitStatus = SubmitStatus.submitting;
    createdMemberId = null;
    passwordErrorText = null;
    snackbarMessage = null;
    _notify();

    try {
      final response = await _service.signUp(request);
      final id = response.result?.memberId;
      if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
      createdMemberId = id;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      submitStatus = SubmitStatus.error;
      final message = writeSignUpErrorMessage(error);
      final status = error.response?.statusCode;
      if (status == 400 && message.contains('비밀번호')) {
        passwordErrorText = message;
      } else {
        snackbarMessage = message;
      }
      // 최종 409: 중복 확인 뒤 그 사이 누군가 같은 값을 가입했다.
      // 체크 표시가 남아 있으면 안 되므로 해당 칸을 duplicated로 되돌려 값을 바꾸게 한다.
      if (status == 409) {
        if (message.contains('이메일')) _email.markDuplicated(request.email);
        if (message.contains('닉네임')) _nickname.markDuplicated(request.nickname);
      }
    } on StateError {
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    } on TypeError {
      // 201인데 body 모양이 명세와 다를 때(result가 객체가 아님 등)
      submitStatus = SubmitStatus.error;
      snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
    }
    _notify();
  }

  /// Snackbar는 한 번만 보여 준다. 화면이 꺼낸 뒤 지운다.
  String? takeSnackbarMessage() {
    final message = snackbarMessage;
    snackbarMessage = null;
    return message;
  }

  /// 닉네임·이메일을 바꾸면 이전 가입 시도의 서버 오류(409 등)도 함께 무효화한다.
  void _clearSubmitError() {
    if (submitStatus == SubmitStatus.error) submitStatus = SubmitStatus.idle;
    snackbarMessage = null;
  }

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

  /// 서버가 최종 가입 단계(409)에서 중복이라고 알려 준 값을 duplicated로 기록한다.
  void markDuplicated(String value) {
    final trimmed = value.trim();
    _requestVersion++;
    _duplicatedValue = trimmed;
    if (_currentValue == trimmed || _currentValue.isEmpty) {
      status = CheckStatus.duplicated;
      errorText = duplicatedMessage;
    }
  }

  /// 화면을 떠날 때 기다리던 응답을 모두 무시하게 한다.
  void invalidate() => _requestVersion++;

  bool _isLatest(int version, String requested) =>
      version == _requestVersion && _currentValue == requested;
}
