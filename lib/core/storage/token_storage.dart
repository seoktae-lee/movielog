import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 액세스 토큰을 저장·조회·삭제하는 규칙. 인증 흐름은 이 인터페이스에만 의존한다.
///
/// 로그인·로그아웃·Interceptor가 [FlutterSecureStorage]를 직접 부르지 않으므로,
/// 테스트에서는 메모리 저장소로 바꿔 끼울 수 있고 저장 방식이 바뀌어도 인증 코드는 그대로다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

/// iOS Keychain / Android Keystore에 암호화해 저장하는 실제 구현.
///
/// `shared_preferences`는 평문 저장이라 토큰을 넣지 않는다. (장르·이메일 같은 비민감 값만)
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'movielog.access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> deleteAccessToken() {
    return _storage.delete(key: _accessTokenKey);
  }
}
