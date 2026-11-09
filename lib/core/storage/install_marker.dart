import 'package:shared_preferences/shared_preferences.dart';

/// (심화) "이 설치에서 앱을 한 번이라도 초기화했는가" flag.
///
/// iOS Keychain 값은 앱을 지워도 남을 수 있다. 반면 shared_preferences는 앱과 함께 지워진다.
/// 그래서 flag가 없으면 "새로 설치됐다"고 보고, Keychain에 남은 이전 토큰을 지운다.
/// 보안 수단도 완벽한 재설치 감지기도 아니다. 백업 복원 상황에 따라 달라질 수 있다.
abstract interface class InstallMarker {
  Future<bool> isInitialized();
  Future<void> markInitialized();
}

class PrefsInstallMarker implements InstallMarker {
  PrefsInstallMarker(this._prefs);

  static const key = 'movielog.install_initialized';

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> isInitialized() async => await _prefs.getBool(key) ?? false;

  @override
  Future<void> markInitialized() => _prefs.setBool(key, true);
}
