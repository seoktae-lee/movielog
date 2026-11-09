import 'package:shared_preferences/shared_preferences.dart';

/// Challenge: 로그인 화면 "이메일 저장".
///
/// shared_preferences는 평문 저장이므로 **이메일만** 넣는다. 비밀번호·토큰은 절대 넣지 않는다.
abstract interface class EmailPreferences {
  /// 저장된 이메일. 저장하지 않았으면 null.
  Future<String?> readSavedEmail();
  Future<void> saveEmail(String email);
  Future<void> clearEmail();
}

class PrefsEmailPreferences implements EmailPreferences {
  PrefsEmailPreferences(this._prefs);

  static const key = 'movielog.saved_email';

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> readSavedEmail() => _prefs.getString(key);

  @override
  Future<void> saveEmail(String email) => _prefs.setString(key, email.trim());

  @override
  Future<void> clearEmail() => _prefs.remove(key);
}
