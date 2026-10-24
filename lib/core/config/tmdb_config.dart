import 'package:flutter_dotenv/flutter_dotenv.dart';

/// TMDB 설정값을 한곳에서 읽는 클래스.
///
/// `.env`의 Key 문자열(`TMDB_ACCESS_TOKEN`)을 여러 파일에서 반복하지 않고,
/// 값이 비었는지 검사하는 코드도 여기에 모은다.
/// Token 원문은 절대 `print`·`debugPrint`로 출력하지 않는다.
abstract final class TmdbConfig {
  static const accessTokenKey = 'TMDB_ACCESS_TOKEN';

  /// `.env`에 저장한 API Read Access Token.
  ///
  /// `dotenv.load()`가 끝나기 전에 읽으면 `NotInitializedError`가 나므로,
  /// 로드 전(테스트 등)에는 빈 문자열을 돌려준다.
  static String get accessToken {
    if (!dotenv.isInitialized) return '';
    return dotenv.env[accessTokenKey] ?? '';
  }

  /// Token이 채워져 있는지. 비어 있으면 요청은 401로 실패한다.
  static bool get hasAccessToken => accessToken.trim().isNotEmpty;
}
