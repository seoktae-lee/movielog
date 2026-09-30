import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 고른 장르를 기기에 저장하고 다시 읽어 오는 클래스.
///
/// 앱을 껐다 켜도 유지돼야 하지만 사라져도 큰일이 아닌 값이라
/// `shared_preferences`가 알맞다.
/// JWT·비밀번호·개인정보처럼 민감한 값은 여기가 아니라
/// `flutter_secure_storage`(iOS Keychain, Android Keystore)에 저장한다.
class GenrePreference {
  /// 테스트에서 가짜 저장소를 넣을 수 있도록 생성자로 받는다.
  GenrePreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// 저장에 쓰는 Key. 읽기와 쓰기가 반드시 같은 값을 써야 한다.
  static const selectedGenresKey = 'selected_genres';

  /// 새 코드에서 권장되는 API. 읽기까지 모두 비동기다.
  final SharedPreferencesAsync _preferences;

  /// 저장된 장르 집합. 저장한 적이 없으면 빈 집합(= 전체)을 돌려준다.
  Future<Set<String>> read() async {
    final saved = await _preferences.getStringList(selectedGenresKey);
    return saved?.toSet() ?? const <String>{};
  }

  /// 선택 장르를 저장한다. 전체(빈 집합)면 Key 자체를 지워 둔다.
  Future<void> save(Set<String> genres) async {
    if (genres.isEmpty) {
      await _preferences.remove(selectedGenresKey);
      return;
    }
    // shared_preferences는 int·double·bool·String·List<String>만 저장할 수 있다.
    // 그래서 Movie 객체가 아니라 장르 문자열 목록만 저장한다.
    await _preferences.setStringList(selectedGenresKey, genres.toList());
  }

  /// 저장값을 지운다.
  Future<void> clear() => _preferences.remove(selectedGenresKey);
}
