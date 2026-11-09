import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/install_marker.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';

/// 앱 전체의 로그인 상태. Router의 redirect가 이 값만 보고 화면을 정한다.
enum AuthStatus {
  /// 앱 시작 직후 저장소·서버 확인 중 → Splash
  initializing,

  /// 토큰이 없거나 정리됨 → 로그인 화면
  signedOut,

  /// 로그인 요청 중 → 로그인 화면 유지(버튼 로딩)
  authenticating,

  /// 로그인됨 → 홈 등 보호 화면
  signedIn,

  /// 네트워크 등으로 세션 확인 실패 → Splash + 다시 시도 (토큰은 지우지 않는다)
  retryRequired,
}

/// 내 정보(GET me) 로딩 상태. 로그인 상태와 따로 둔다. (내 정보가 실패해도 로그아웃이 아니다)
enum MemberLoadStatus { idle, loading, success, error }

/// 로그인·세션 복원·만료·로그아웃을 한곳에서 관리하는 ViewModel.
///
/// 화면 이동은 하지 않는다. [status]만 바꾸면 GoRouter가 `refreshListenable`로 알아채고 redirect한다.
///
/// [sessionVersion]: 로그인·로그아웃·만료마다 1씩 오른다. 요청 시작 때 값을 기억해 두고,
/// 응답이 왔을 때 값이 달라졌으면 "이전 세션의 늦은 응답"이므로 버린다.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(
    this._authApi,
    this._memberApi,
    this._storage, {
    InstallMarker? installMarker,
  }) : _installMarker = installMarker; // ignore: prefer_initializing_formals

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  /// (심화) iOS 재설치 뒤 Keychain에 남은 토큰을 지우기 위한 최초 설치 flag. 없으면 건너뛴다.
  final InstallMarker? _installMarker;
  bool _installChecked = false;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;

  /// Splash 재시도·로그인 실패·저장소 오류처럼 화면에 보여 줄 문구.
  String? message;

  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;

  /// 토큰 만료로 쫓겨났을 때만 true. 로그인 화면이 Snackbar를 한 번 보여 주고 끈다.
  /// 직접 로그아웃이나 로그인 실패(AUTH401_1)에서는 켜지 않는다.
  bool sessionExpired = false;

  /// 저장소에서 토큰을 지우는 중. 이때 새 로그인을 막는다. (삭제가 새 토큰을 지우지 않게)
  bool storageCleanupInProgress = false;

  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 앱 시작 시: 저장소의 토큰을 읽고, 있으면 GET me로 서버에 유효한지 확인한다.
  ///
  /// 토큰이 있다는 이유만으로 signedIn을 확정하지 않는다. 만료된 토큰으로 홈에 들어갔다가
  /// 뒤늦게 401을 받는 일을 막는다. 네트워크 실패면 토큰을 지우지 않고 retryRequired로 둔다.
  Future<void> restoreSession() async {
    if (storageCleanupInProgress || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    _notify();
    try {
      await _clearTokenIfFreshInstall();
      final token = await _storage.readAccessToken();
      if (!_isCurrent(version)) return;
      if (token == null || token.isEmpty) {
        status = AuthStatus.signedOut;
      } else {
        final verifiedMember = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;
        member = verifiedMember;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      if (apiErrorCode(error) == 'MEMBER404_1') {
        // 토큰은 유효한데 회원이 없다(탈퇴 등). 이 토큰으로는 더 진행할 수 없다.
        await _clearCurrentSession(expired: true);
        return;
      }
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    if (_isCurrent(version)) _notify();
  }

  /// (심화) 최초 설치 flag가 없으면 이전 설치에서 남은 토큰을 지운 뒤 flag를 기록한다.
  /// 보안 수단도, 완벽한 재설치 감지기도 아니다. 앱 실행마다 한 번만 확인한다.
  Future<void> _clearTokenIfFreshInstall() async {
    final marker = _installMarker;
    if (marker == null || _installChecked) return;
    if (!await marker.isInitialized()) {
      await _storage.deleteAccessToken();
      await marker.markInitialized(); // 삭제가 성공한 뒤에만 기록한다.
    }
    _installChecked = true;
  }

  /// 로그인. 성공하면 토큰을 저장하고 signedIn으로 바꾼다. 내 정보는 MainScreen이 불러온다.
  ///
  /// 실패 문구를 하나로 뭉치지 않는다: 입력 오류(AUTH401_1)·통신 실패·토큰 저장 실패.
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        status == AuthStatus.authenticating) {
      return;
    }
    status = AuthStatus.authenticating;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    final version = ++_sessionVersion;
    _notify();
    try {
      final result = await _authApi.login(
        LoginRequest(email: email, password: password),
      );
      if (!_isCurrent(version)) return;
      final writing = _storage.saveAccessToken(result.accessToken);
      _tokenWrite = writing;
      try {
        await writing;
      } finally {
        if (identical(_tokenWrite, writing)) _tokenWrite = null;
      }
      if (!_isCurrent(version)) return;
      // 신규 로그인: 토큰 저장 → signedIn → MainScreen.loadMember().
      // 앱 재시작은 restoreSession()의 GET me 검증 뒤에만 signedIn이다.
      status = AuthStatus.signedIn;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = switch (apiErrorCode(error)) {
        'AUTH401_1' => '이메일 또는 비밀번호를 확인해 주세요.',
        'COMMON400' => apiErrorMessage(error) ?? '입력값을 확인해 주세요.',
        _ => '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
      };
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }
    _notify();
  }

  /// 내 정보 불러오기. MainScreen이 처음 열릴 때 한 번 호출한다.
  ///
  /// 401(AUTH401_2/3/4)이면 세션을 정리하고, 네트워크 실패면 로그아웃하지 않고 error로 남긴다.
  Future<void> loadMember({bool force = false}) async {
    if (_disposed || status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return; // 이미 있으면 다시 부르지 않는다.

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·계정 전환 뒤 늦게 온 응답
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      memberStatus = MemberLoadStatus.error;
    } catch (_) {
      if (!_isCurrent(version)) return;
      memberStatus = MemberLoadStatus.error;
    }
    _notify();
  }

  /// 프로필 수정 성공 응답(최신 내 정보)으로 교체한다. GET me를 다시 부르지 않는다.
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    memberStatus = MemberLoadStatus.success;
    _notify();
  }

  /// 다른 ViewModel이 보호 요청에서 AUTH401_2/3/4를 받았을 때 부르는 공개 진입점.
  ///
  /// [requestVersion]은 그 요청을 **보낼 때**의 [sessionVersion]이다.
  /// 동시에 보낸 요청 여러 개가 401을 받아도 첫 번째만 세션을 정리하고(Snackbar·이동 한 번),
  /// 이전 세션의 늦은 401이 새 로그인 세션을 지우지 않는다.
  Future<void> expireSession(int requestVersion) async {
    if (requestVersion != _sessionVersion || status != AuthStatus.signedIn) {
      return;
    }
    await _clearCurrentSession(expired: true);
  }

  /// 직접 로그아웃. 저장소와 메모리 세션을 비우지만 만료 Snackbar는 켜지 않는다.
  /// 서버에서 토큰이 즉시 폐기된다고 보장하지는 않는다. (클라이언트 세션만 정리)
  Future<void> logout() => _clearCurrentSession(expired: false);

  void consumeSessionExpired() {
    sessionExpired = false;
  }

  /// 로그인 화면의 이전 실패 문구를 지운다. (회원가입을 마치고 돌아왔을 때 등)
  /// 로그인 요청 중이거나 저장소 정리 중에는 그 문구가 의미 있으므로 건드리지 않는다.
  void clearMessage() {
    if (_disposed || message == null || status != AuthStatus.signedOut) return;
    message = null;
    _notify();
  }

  Future<void> _clearCurrentSession({required bool expired}) async {
    if (_disposed || storageCleanupInProgress) return;
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();
    try {
      // 진행 중이던 토큰 저장이 끝난 뒤 지운다. 순서가 바뀌면 지운 뒤에 토큰이 다시 써진다.
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장 실패여도 삭제는 시도한다.
      }
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version)) {
        message = '저장된 인증 정보를 지우지 못했어요. 앱을 다시 실행하기 전에 확인해 주세요.';
      }
    } finally {
      storageCleanupInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
