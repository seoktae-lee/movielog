# 8주차 Frontend 노션 제출본 (원고)

> 태이의 워크북 / 8주차 - JWT 토큰 기반 로그인 및 세션 복원 페이지에 붙여넣는 원고. 워크북 순서 그대로다.
> `🖼️` 자리에 이미지/GIF를 넣는다. **토글 안에 넣지 말 것** (채점에서 빠질 수 있음).
> 토큰·비밀번호·개인 이메일은 어디에도 넣지 않는다. 캡처의 이메일은 회색 상자로 가려 두었다.

## 📌 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | (작성 예정) |
| 브랜치 | `feature/week-8` |
| 사용 API | 워크북 Swagger v7 (`https://workbook.devnoco.com/v7`) + TMDB |
| 검증 플랫폼 | iOS 시뮬레이터 iPhone 18 Pro (iOS 27.0) — 로그인·Keychain·재시작 복원 / Chrome(Flutter web) — 나머지 화면 |
| 검증 | `flutter analyze` 0건 / `flutter test` 144개 통과 / 실제 v7 서버로 로그인·내 정보·닉네임 수정·평점 등록·수정·삭제·만료·로그아웃 확인 |

## 📸 스터디 인증

- [x] 로그인 실패와 로그인 성공→내 정보 화면
  🖼️ `week8-02-ios-login-401-wrong-account.png` — 없는 계정 → `AUTH401_1` → "이메일 또는 비밀번호를 확인해 주세요." Form 문구만, 만료 처리 없음
  🖼️ `week8-01-ios-login-400-email-format.png` — 이메일 형식 오류 → 서버 `COMMON400` message
  🖼️ `week8-04-ios-login-success-home.png` → `week8-06-mypage-me.png` — 로그인 → 홈 → 마이페이지에 GET me의 닉네임·가입일·이메일
- [x] 앱 재시작→세션 확인→홈 진입 영상
  🖼️ `week8-gif-ios-restart-restore.gif` — iOS에서 앱 종료 → 다시 실행 → 로그인 화면 없이 GET me 200 → "태이님" 홈
- [x] 닉네임 수정 성공/409 화면
  🖼️ `week8-08-profile-409-duplicate.png` (MEMBER409_1, 입력값 유지) · `week8-11-profile-saved.png` → `week8-12-mypage-updated.png` (저장 → 마이페이지 즉시 반영) · 영상 `week8-gif-profile-edit.gif`
- [x] 토큰 기반 평점 등록→수정→삭제 영상
  🖼️ `week8-gif-rating-crud.gif` — POST /v7/ratings 201 → "내 평점 4.0" → 내가 등록한 평점 → PATCH 200 result로 카드 갱신 → DELETE 200 → Empty
- [x] 만료/무효 토큰 안내와 로그인 화면 이동
  🖼️ `week8-gif-expiry.gif` · `week8-24-expiry-login-snackbar.png` — 보호 요청이 `AUTH401_3` → 토큰 삭제 → /login + "로그인이 만료됐어요. 다시 로그인해 주세요." 1회
- [x] 로그아웃 후 보호 화면 접근 차단
  🖼️ `week8-gif-logout-redirect.gif` — 앱바 로그아웃 → /login(만료 Snackbar 없음) → `/my`로 직접 이동해도 /login
- [x] 토큰·비밀번호가 가려진 Network/Console 증거

```
[MovieLog 응답 Body] {..., result: {nickname: 태이, accessToken: ***}}          ← 로그인 응답 Body도 가림
[MovieLog 보호 요청] GET https://workbook.devnoco.com/v7/members/me
[MovieLog 보호 요청 Header] {Authorization: Bearer ***}
[MovieLog 보호 요청] POST https://workbook.devnoco.com/v7/ratings               ← path·body에 memberId 없음
[MovieLog 보호 응답] 201  result: {ratingId: 57, movieId: 155, score: 4, ...}
[MovieLog 보호 요청] PATCH https://workbook.devnoco.com/v7/ratings/58 → 200 result: Rating
[MovieLog 보호 요청] DELETE https://workbook.devnoco.com/v7/ratings/59 → 200 {..., result: null}
[MovieLog 보호 오류 Body] {code: RATING409_1, message: 이미 이 영화에 평점을 남기셨습니다.}
[MovieLog 보호 오류 Body] {code: AUTH401_3, message: 유효하지 않은 토큰입니다.}
[TMDB 요청 Header] {Authorization: Bearer ***, accept: application/json}       ← TMDB는 별도 Client·별도 Token
```

비밀번호는 요청 Body를 로그로 찍지 않으므로 콘솔에 남지 않는다. 전체 기록: 저장소 `docs/week8-network-log.md`

- [x] Android 또는 iOS 실제 선택 환경의 secure storage 검증 — **iOS 시뮬레이터**

| 확인 | 결과 |
| --- | --- |
| 평문 설정 파일 `Library/Preferences/com.example.movielog.plist` | `movielog.install_initialized`, `movielog.saved_email` 두 키뿐 — 토큰 없음 |
| 앱 컨테이너 전체에서 `access_token` 검색 | 없음 |
| 시뮬레이터 Keychain DB(genp) | `…com.example.movielog` 접근 그룹 항목 1건, 생성 시각 = 로그인 시각, 값은 암호화 (값은 읽지 않음) |
| 앱 종료 → 재실행 / 재빌드·재설치 | 두 경우 모두 토큰이 남아 GET me 200 → 홈 |
| 검증하지 않은 것 | Android, iOS 앱 삭제 후 재설치 시나리오 |

## 🎯 핵심 개념

1. **인증 vs 인가** — 인증은 "누구인가"(로그인, accessToken, GET me), 인가는 "이 작업을 해도 되는가"(본인 평점만 수정·삭제). 토큰이 없거나 무효면 401, 인증은 됐지만 권한이 없으면 403.
2. **401은 세 종류로 나눠 본다** — 로그인 `AUTH401_1`은 Form 입력 오류(세션과 무관), 보호 요청 `AUTH401_2/3/4`(없음/무효/만료)만 현재 세션을 정리한다. 403(`RATING403_1`)은 로그아웃 사유가 아니다.
3. **v6 → v7은 URL만 바뀌는 게 아니다** — path에서 memberId가 빠지고 `Authorization: Bearer`로 사용자 식별, 등록·수정 result가 Rating 객체, 삭제 성공이 204 → 200(result null), 오류 code가 도메인별(AUTH/MEMBER/RATING)로 바뀐다. 경로·파서·status·code를 함께 고친다.
4. **토큰 저장은 secure storage** — `shared_preferences`는 평문이라 토큰을 넣지 않는다. `flutter_secure_storage`가 iOS Keychain / Android Keystore에 암호화해 write/read/delete한다. `TokenStorage` 인터페이스로 감싸 인증 코드가 저장소 구현을 모르게 한다.
5. **Dio Interceptor로 Bearer 붙이기** — `AuthInterceptor.onRequest`가 요청마다 저장소에서 토큰을 읽어 Header를 붙인다. 이전 요청의 Header를 재사용하지 않도록 먼저 지운다. 저장소 읽기 실패는 서버 401과 다른 오류로 reject한다.
6. **공개용·보호용 Client 분리** — 로그인·중복 확인·회원가입·유저별 평점 조회는 공개용(Interceptor 없음), 내 정보·평점 쓰기는 보호용. Interceptor 안에서도 host(`workbook.devnoco.com`)와 보호 path를 한 번 더 확인한다. TMDB Client와는 끝까지 합치지 않는다(TMDB Token과 MovieLog JWT를 섞지 않는다).
7. **토큰이 있다고 로그인된 게 아니다(세션 복원)** — 앱 시작 시 토큰을 읽고 GET me가 성공해야 signedIn. 네트워크 실패는 `retryRequired`(토큰 유지 + 다시 시도), 401만 토큰 삭제.
8. **AuthStatus 5개** — `initializing`(Splash) / `signedOut`(로그인) / `authenticating`(로그인 버튼 로딩) / `signedIn`(보호 화면) / `retryRequired`(Splash + 다시 시도).
9. **GoRouter redirect + refreshListenable** — 화면 이동 규칙을 `authRedirect(status, location)` 한 곳에 둔다. `redirect`는 이동할 때만 불리므로 `refreshListenable: authViewModel`로 상태 변화에도 다시 검사하게 한다. redirect 안에서는 상태만 읽고 API를 부르지 않는다.
10. **Router는 한 번만 만든다** — redirect가 AuthViewModel을 알아야 해서 `static final router` 대신 `createRouter(auth)`. build에서 만들면 다시 그릴 때마다 위치가 초기화되므로 StatefulWidget의 initState에서 한 번 만들고, 첫 프레임 뒤 `restoreSession()`.
11. **신규 로그인과 재시작은 흐름이 다르다** — 신규 로그인: 토큰 저장 → signedIn → `MainScreen`이 `loadMember()`. 재시작: `restoreSession()`이 GET me로 검증하며 member까지 채운다. 로그인 함수에 GET me를 중복으로 넣지 않는다.
12. **sessionVersion** — 로그인·로그아웃·만료마다 1 증가. 요청 시작 때 값을 기억하고 응답 때 달라졌으면 버린다. 이전 세션의 늦은 401이 새 로그인 세션을 지우지 못하고, 동시에 온 401 여러 개도 정리·Snackbar·이동이 한 번만 일어난다.
13. **만료 안내는 플래그로** — 직접 로그아웃·로그인 실패도 signedOut이라 상태만으로는 "만료로 쫓겨났는지" 모른다. 만료 정리 때만 `sessionExpired = true`, 로그인 화면이 Snackbar를 띄우기 전에 `consumeSessionExpired()`로 끈다. ViewModel은 BuildContext로 Snackbar를 띄우지 않는다.
14. **PATCH me 성공 응답으로 member 교체** — 수정 result가 최신 내 정보라 GET me를 다시 부르지 않는다. 마이페이지는 `watch`/`select`로 구독해야 바로 다시 그려진다. 같은 닉네임이면 요청 없이 완료.
15. **TMDB id ↔ MovieLog movieId** — 평점의 movieId는 TMDB 영화 id. 영화 정보를 못 찾아도 평점을 지우지 않고 `영화 #{movieId}` placeholder로 보여 준다.
16. **계약에 없는 값은 추정하지 않는다** — v7 로그인·내 정보 응답에 memberId가 없고 토큰 기반 내 평점 목록 GET도 없다. JWT payload를 열어 memberId를 꺼내지 않았고, 재시작 뒤 전체 복원은 완료 기능으로 표시하지 않는다.

## 🧪 Guided Practice A — 로그인부터 내 정보까지

1. `flutter_secure_storage`를 추가하고 `TokenStorage`(`SecureTokenStorage`)로 토큰 저장·조회·삭제를 한곳에 모은다.

```dart
// lib/core/storage/token_storage.dart
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}
```

2. 워크북 Client를 공개용과 보호용으로 나누고, 보호용에만 `AuthInterceptor`를 등록한다.

```dart
// lib/core/network/auth_interceptor.dart — 보호 경로에만 Bearer
static bool isProtected(Uri uri) =>
    uri.host == 'workbook.devnoco.com' &&
    (uri.path == '/v7/members/me' || uri.path == '/v7/ratings' || uri.path.startsWith('/v7/ratings/'));
```

3. 공개 Client로 로그인하고 `LoginResult.accessToken`을 secure storage에 저장한다. (result에 memberId 없음)
4. `AuthViewModel`에 5개 상태와 `login()`을 연결한다. 실패 문구는 AUTH401_1 / 통신 실패 / 저장 실패로 나눈다.

```dart
message = switch (apiErrorCode(error)) {
  'AUTH401_1' => '이메일 또는 비밀번호를 확인해 주세요.',
  'COMMON400' => apiErrorMessage(error) ?? '입력값을 확인해 주세요.',
  _ => '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
};
```

5. GoRouter에 `/login`을 추가하고 `redirect`·`refreshListenable`로 상태별 이동을 연결한다.

```dart
String? authRedirect(AuthStatus status, String location) {
  const publicPaths = {'/login', '/register'};
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);
  return switch (status) {
    AuthStatus.initializing || AuthStatus.retryRequired => atStart ? null : '/start',
    AuthStatus.signedOut || AuthStatus.authenticating => atPublic ? null : '/login',
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}
```

6. `MainScreen`을 Stateful로 바꾸고 첫 프레임 뒤 `loadMember()`로 GET me → `AuthViewModel.member`. (build 중 notifyListeners 오류를 피하려고 addPostFrameCallback)
7. 앱 재시작 → 토큰 읽기 → GET me(`restoreSession`) → 홈. 🖼️ `week8-gif-ios-restart-restore.gif`

완료 조건 확인:
- [x] 토큰 원문을 화면·로그·캡처에 표시하지 않는다 (Header·로그인 Body 모두 `***`)
- [x] 네트워크 실패는 자동 로그아웃이 아니라 Splash 재시도 (테스트 "네트워크 실패면 토큰을 지우지 않고 retryRequired")
- [x] 재시작 시 GET me 성공 뒤에만 홈
- [x] 로그인 직후 어느 탭으로 들어가도 마이페이지에 닉네임 (홈 인사말도 GET me 닉네임) 🖼️ 05·06

## 🧪 Guided Practice B — 평점 등록 전환

1. v6 Service의 memberId 인자를 모두 제거했다.
2. `RatingApiService(publicDio, authDio)` — 조회는 공개, 등록·수정·삭제는 보호 Client. ViewModel은 Dio를 모른다.

```dart
Future<RatingDto> createRating(CreateRatingRequest request) async {
  final response = await _authDio.post('/v7/ratings', data: request.toJson());
  return parseRatingResult(response.data); // v7 result = Rating 객체
}

Future<void> deleteRating(int ratingId) async {
  final response = await _authDio.delete('/v7/ratings/$ratingId');
  if (response.statusCode != 200) throw StateError('예상하지 못한 삭제 응답'); // 204 아님
}
```

3. 등록 body는 `{movieId, score, comment?}`뿐, memberId 없음.
4. 등록 result(Rating)로 상세의 "내 평점"과 세션 평점 보관함을 바로 갱신. 🖼️ `week8-15-rating-created.png`
5. 401은 `expireSession(요청 시점 sessionVersion)`, 403·409는 Dialog 안내만.

```dart
} on DioException catch (error) {
  if (_disposed || version != _auth.sessionVersion) return; // 로그아웃·회원 전환 뒤 늦은 응답
  submitStatus = SubmitStatus.error;
  submitMessage = writeErrorMessage(error);
  if (isSessionExpiredError(error)) await _auth.expireSession(version);
}
```

완료 조건 확인:
- [x] 등록 path·body에 memberId 없음, Authorization만으로 등록 (로그 `POST /v7/ratings`, Header `Bearer ***`)
- [x] 등록 result로 화면 갱신
- [x] 401이면 세션 정리 + /login 🖼️ `week8-gif-expiry.gif`
- [x] 409는 안내만, 로그인 유지 🖼️ `week8-16-rating-409.png` / 403은 테스트로 확인 (아래 참고)
- [x] 로그아웃·회원 전환 뒤 늦은 응답 무시 (테스트 "로그아웃 뒤 늦게 도착한 수정 응답은 반영하지 않는다")

## 🚀 Required Mission

- [x] 현재 세션에서 생성한 Rating을 v7 PATCH/DELETE로 변경 🖼️ 17~22 · `week8-gif-rating-crud.gif`
  - v7에 토큰 기반 내 평점 목록이 없어서 "내가 등록한 평점"은 `SessionRatingStore`(이번 로그인의 등록 result)를 보여 준다. 세션이 바뀌면 스스로 비운다.
  - 수정은 PATCH 전체 교체라 Dialog에 기존 score·comment를 채워 두 값을 함께 보내고, result(Rating)로 그 카드만 바꾼다. GET 재조회 없음.
- [x] v7 성공 status/result와 도메인 오류 code로 파서 변경 — `parseRatingResult`, 삭제 200, `RATING403_1/404_1/409_1`
- [x] 마이페이지 GET me 표시 + `/my/profile/edit`에서 PATCH me → 성공 시 member 교체 🖼️ 06·07·11·12
- [x] 닉네임 오류 구분: 2~12자(요청 전) 🖼️ 09 · MEMBER409_1(입력 유지) 🖼️ 08 · 네트워크 실패(Snackbar, 로그아웃 없음, 테스트)
- [x] 재시작 복원·만료·로그아웃·보호 화면 redirect 🖼️ gif 3종
- [x] 앱바 로그아웃 → 토큰·member 삭제 → /login 🖼️ 25·26
- [x] 만료로 /login에 오면 Snackbar, 직접 로그아웃·로그인 실패에서는 표시 안 함 🖼️ 24 vs 26·02

```dart
// lib/screens/login_screen.dart — 열려 있을 때 만료 + 이미 만료된 채로 열릴 때 둘 다
_auth.addListener(_showSessionExpired);
WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());

void _showSessionExpired() {
  if (!mounted || !_auth.sessionExpired) return;
  _auth.consumeSessionExpired(); // 먼저 꺼서 반복 방지
  ScaffoldMessenger.of(context)..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')));
}
```

403(RATING403_1) 실서버 재현은 하지 않았다. 다른 회원의 평점에 수정 요청을 보내야 하는 방식이라 공용 서버의 남의 데이터를 건드리게 된다. 대신 Widget 테스트 "수정 403(남의 평점)이면 Dialog에 안내만 하고 로그인 상태를 유지한다"로 확인했다.

## ⭐ Challenge Mission

- [x] "이메일 저장" 체크박스 — `shared_preferences`에 **이메일만**, 로그인 성공 뒤에만 저장/해제. 비밀번호·토큰 저장 안 함 🖼️ 24·26 (만료·로그아웃 후 이메일이 채워짐)
- [x] 마이페이지 내 정보 로딩·실패·재시도 — `memberStatus`가 loading이면 화면 전체 인디케이터, error면 "내 정보를 불러오지 못했어요" + 다시 시도(같은 세션 유지)
- [x] 가입일 "2026.11.09 가입" — UTC를 기기 시간대로 바꾼 뒤 자른다 🖼️ 06
- [x] 변경 내용이 있을 때 뒤로가기 확인 Dialog — 계속 수정이면 머물고, 나가기면 마이페이지 🖼️ 10
- [x] (심화) iOS 재설치 flag — `movielog.install_initialized`가 없으면 Keychain 토큰 삭제 후 기록. 첫 실행에 flag 기록까지 확인, **실제 삭제 후 재설치는 검증하지 않음**

## 🛠 트러블슈팅 기록

(저장소 `docs/week8-troubleshooting.md`에 양식 전체. 아래는 요약)

1. **프로필 저장 성공 후 화면이 안 닫힘** — 보호 PATCH me 200. PopScope가 직전 프레임의 canPop(false)으로 pop을 막았다 → `_leaving`을 setState로 반영한 **다음 프레임**에 pop. 회귀 테스트 추가(고치기 전 코드에서 실패 확인).
2. **가입 후 로그인 화면에 이전 실패 문구** — AUTH401_1 문구가 AuthViewModel.message에 남음 → `clearMessage()`를 didUpdateWidget에서 호출. 🖼️ 03
3. **가입 후 이메일이 안 채워짐** — `go('/login', extra)`로 돌아오면 기존 LoginScreen State가 재사용돼 initState가 안 불림 → didUpdateWidget에서 채움.
4. **로그인 응답 Body로 JWT 원문이 콘솔에 찍힐 뻔함** — 기존 로그 Interceptor는 Header만 가렸다 → Body의 accessToken도 `***`.
5. **Widget 테스트 30개가 SharedPreferencesAsync 오류** — 가짜를 주입해도 실제 객체를 먼저 만들었다 → 필요할 때만 생성.
6. **재시작 후 내 평점이 비고 같은 영화 재등록은 409** — 버그가 아니라 v7 계약 한계(memberId·토큰 기반 목록 없음). 화면에 "이번 로그인에서 등록한 평점", "(v7 API 한계)"로 명시.
7. **Xcode 27에 Simulator.app 없음 / 재시작 영상에 옛 코드** — DeviceHub.app 사용, 핫 리로드는 설치 번들에 안 들어가므로 flutter run으로 재설치 후 재촬영(Keychain 토큰은 유지).

## ✅ 최종 체크리스트

- [x] 비밀번호를 저장하거나 로그에 남기지 않습니다. (요청 Body 로그 없음, `LoginRequest.toString`도 `***`)
- [x] 보호 대상 host/path에만 Bearer를 붙입니다. (테스트: 공개 경로·로그인·TMDB에는 Header 없음)
- [x] 로그인 401·보호 401·403을 구분합니다.
- [x] 앱 재시작은 GET me 검증 뒤 signedIn이 됩니다. 신규 로그인은 토큰 저장 뒤 MainScreen.loadMember()로 내 정보를 불러옵니다.
- [x] 네트워크 실패에 토큰을 자동 삭제하지 않습니다.
- [x] v7 경로·parser·status·error code를 함께 변경했습니다.
- [x] TMDB Token과 MovieLog JWT를 서로 다른 Client에만 보냅니다.
- [x] 평점 `movieId`로 TMDB 영화 정보를 연결하며 없는 정보는 placeholder 처리합니다. (`영화 #{movieId}`)
- [x] 로그아웃/회원 전환 뒤 이전 응답을 무시합니다. (sessionVersion)
- [x] 내 평점 전체 복원 계약의 한계를 문서화했습니다.
- [x] 선택한 실제 플랫폼에서 secure storage를 검증했습니다. (iOS 시뮬레이터)
- [x] flutter analyze와 Guided/Required 수동 검증 결과를 기록했습니다. (analyze 0건, 테스트 144개, 실서버 검증 위 인증 항목)

## 📮 제출 양식

```
PR 링크: (작성 예정)
로그인→GET me 증거: week8-04 → week8-06, 로그 POST /v7/auth/login 200 → GET /v7/members/me 200 (Bearer ***)
재시작 복원 / 로그아웃 / 만료 증거: week8-gif-ios-restart-restore.gif / week8-gif-logout-redirect.gif / week8-gif-expiry.gif
닉네임 수정 증거: week8-gif-profile-edit.gif (MEMBER409_1, 2~12자, 성공 후 마이페이지 즉시 반영)
평점 v6→v7 변경 표와 동작 영상: 아래 표 + week8-gif-rating-crud.gif
TMDB id → MovieLog movieId → 영화 정보 결합 증거: 상세 "movieId 155"로 POST {movieId: 155} → 내가 등록한 평점 카드에 TMDB 제목·포스터
401/403/409 처리: AUTH401_1 Form 문구(02) / AUTH401_3 세션 정리+Snackbar(24) / RATING409_1 Dialog 안내(16) / MEMBER409_1 필드 오류(08) / RATING403_1 테스트
보안 저장 검증 플랫폼·결과: iOS 시뮬레이터 — 토큰은 Keychain에만, 평문 plist엔 이메일·설치 flag뿐, 재시작·재설치 후 복원. Android·실제 재설치 미검증
토큰/비밀번호 비노출 확인: Header Bearer ***, 로그인 Body accessToken ***, 비밀번호 로그 없음, 캡처의 이메일 가림
트러블슈팅: 7건 (위 요약, 저장소 docs/week8-troubleshooting.md)
```

| 동작 | v6 | v7 |
| --- | --- | --- |
| 등록 | `POST /v6/members/{memberId}/ratings` → 201, result 안 읽음 | `POST /v7/ratings` → 201, result = Rating |
| 수정 | `PATCH /v6/members/{memberId}/ratings/{id}` → result null | `PATCH /v7/ratings/{id}` → result = Rating |
| 삭제 | 204, body 없음 | 200, result null |
| 사용자 식별 | path의 memberId | Authorization: Bearer |
| 오류 code | COMMON 계열 | AUTH / MEMBER / RATING 계열 |

## 💭 8주차 회고

(공부 후 작성)
