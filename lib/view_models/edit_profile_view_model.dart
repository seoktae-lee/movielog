import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/services/member_api_service.dart';
import 'auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

/// 프로필 수정 화면 전용 ViewModel. 닉네임만 바꿀 수 있다. (`PATCH /v7/members/me`)
///
/// 오류는 보여 줄 위치로 나눈다.
/// - 입력칸 문제(길이·중복) → [nicknameError] (필드 아래, 입력값 유지)
/// - 입력과 무관한 문제(네트워크) → [message] (Snackbar, 로그아웃하지 않음)
/// - 세션 만료(AUTH401_2/3/4) → AuthViewModel이 세션 정리, Router가 /login으로
class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);

  final MemberApiService _memberApi;
  final AuthViewModel _auth;

  EditProfileStatus status = EditProfileStatus.idle;
  String? nicknameError;
  String? message;
  bool _disposed = false;

  bool get isSaving => status == EditProfileStatus.saving;

  /// 서버와 같은 규칙(2~12자)을 요청 전에 먼저 검사해 불필요한 통신을 줄인다.
  String? validateNickname(String value) {
    final nickname = value.trim();
    if (nickname.isEmpty) return '닉네임을 입력해 주세요.';
    if (nickname.length < 2 || nickname.length > 12) {
      return '닉네임은 2~12자로 입력해 주세요.';
    }
    return null;
  }

  /// 입력이 바뀌면 이전 오류를 지운다. (중복이었던 값을 고치는 중)
  void onNicknameChanged() {
    if (nicknameError == null && message == null) return;
    nicknameError = null;
    message = null;
    _notify();
  }

  /// 저장 성공이면 true. 화면은 true일 때만 Snackbar + pop 한다.
  Future<bool> save(String input) async {
    if (isSaving) return false; // 중복 탭 방지
    if (_disposed || _auth.status != AuthStatus.signedIn) return false;
    final current = _auth.member;
    if (current == null) return false;

    final version = _auth.sessionVersion;
    final nickname = input.trim();
    nicknameError = validateNickname(nickname);
    message = null;
    if (nicknameError != null) {
      _notify();
      return false;
    }

    // 현재 닉네임과 같으면 요청 없이 완료. 서버도 자기 자신은 409로 보지 않지만 부를 이유가 없다.
    if (nickname == current.nickname) {
      status = EditProfileStatus.success;
      _notify();
      return true;
    }

    status = EditProfileStatus.saving;
    _notify();

    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (!_isSameSession(version)) return false;
      _auth.updateMember(updated); // 마이페이지가 바로 새 닉네임을 보여 준다.
      status = EditProfileStatus.success;
      _notify();
      return true;
    } on DioException catch (error) {
      if (!_isSameSession(version)) return false;
      status = EditProfileStatus.failure;
      final code = apiErrorCode(error);
      switch (code) {
        case 'AUTH401_2' || 'AUTH401_3' || 'AUTH401_4':
          // 안내 Snackbar와 이동은 로그인 화면과 Router가 맡는다.
          await _auth.expireSession(version);
          return false;
        case 'MEMBER409_1':
          nicknameError = '이미 사용 중인 닉네임이에요.'; // 입력값은 그대로 둔다.
        case 'COMMON400':
          nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
        case 'MEMBER404_1':
          message = '회원 정보를 찾을 수 없어요.';
        default:
          message = '네트워크 상태를 확인하고 다시 시도해 주세요.'; // 로그아웃하지 않는다.
      }
    } catch (_) {
      if (!_isSameSession(version)) return false;
      status = EditProfileStatus.failure;
      message = '알 수 없는 오류가 발생했어요.';
    }
    _notify();
    return false;
  }

  /// 화면이 닫혔거나, 그사이 로그아웃·계정 전환이 있었으면 응답을 반영하지 않는다.
  bool _isSameSession(int version) =>
      !_disposed &&
      version == _auth.sessionVersion &&
      _auth.status == AuthStatus.signedIn;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
