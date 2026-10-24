import 'package:flutter_dotenv/flutter_dotenv.dart';

/// MovieLog 자체 백엔드(Spring) 주소.
///
/// iOS 시뮬레이터와 웹은 Mac의 localhost를 그대로 쓴다.
/// Android 에뮬레이터라면 `.env`에 `MOVIELOG_API_BASE_URL=http://10.0.2.2:8080`을 넣는다.
abstract final class MovieLogApiConfig {
  static const baseUrlKey = 'MOVIELOG_API_BASE_URL';
  static const defaultBaseUrl = 'http://localhost:8080';

  static String get baseUrl {
    if (!dotenv.isInitialized) return defaultBaseUrl;
    final value = dotenv.env[baseUrlKey]?.trim() ?? '';
    return value.isEmpty ? defaultBaseUrl : value;
  }

  /// 로그인(7주차) 전까지 "나"로 쓰는 회원. 시드 데이터의 1번 회원('수현')이다.
  static const currentMemberId = 1;
}
