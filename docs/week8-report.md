# 8주차 리포트 — JWT 토큰 기반 로그인과 세션 복원

## 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 브랜치 | `feature/week-8` (feature/week-7에서 분기) |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/10 |
| 사용 API | 워크북 Swagger **v7** — 로그인, 내 정보 GET·PATCH, 평점 등록·수정·삭제(토큰), 유저별 평점 조회(공개), 회원가입·중복 확인 + TMDB |
| 검증 플랫폼 | **iOS 시뮬레이터**(iPhone 18 Pro, iOS 27.0) — 로그인·Keychain·재시작 복원 / **Chrome**(Flutter web debug) — 나머지 화면 |
| 검증 | `flutter analyze` 0건 / `flutter test` 144개 통과 / 실제 서버 요청 기록 [week8-network-log.md](week8-network-log.md) |

## 구현 내용

| 영역 | 파일 |
| --- | --- |
| 오류 code | `lib/core/network/api_error.dart` — `apiErrorCode`·`apiErrorMessage`, `sessionExpiredCodes`(AUTH401_2/3/4) |
| 토큰 저장 | `lib/core/storage/token_storage.dart` — `TokenStorage` 인터페이스 + `SecureTokenStorage`(flutter_secure_storage 11.2) |
| Client | `movie_log_client.dart` — 공개용 `createMovieLogClient` / 보호용 `createAuthMovieLogClient` · `auth_interceptor.dart`(host·path 확인 후 Bearer) |
| 모델 | `login_models.dart`(`LoginRequest`·`LoginResult`, toString에서 비밀번호·토큰 가림) · `member_info.dart`(`MemberInfo`, `parseMemberInfo`, `formatJoinedDate`) |
| Service | `auth_api_service.dart`(공개) · `member_api_service.dart`(보호, GET·PATCH me) · `rating_api_service.dart`(v7, Dio 두 개) · `sign_up_service.dart`(v7 경로) |
| ViewModel | `auth_view_model.dart`(`AuthStatus` 5개, `restoreSession`·`login`·`loadMember`·`expireSession`·`logout`, `sessionVersion`) · `edit_profile_view_model.dart` · `session_rating_store.dart`(신규) · `movie_detail_view_model.dart`·`my_ratings_view_model.dart`(v7) |
| 화면 | `splash_screen.dart`(구 StartScreen, 확인 중/재시도) · `login_screen.dart` · `edit_profile_screen.dart` · `main_screen.dart`(Stateful, GET me) · `my_page_screen.dart`(내 정보·로그아웃) · `home_screen.dart`(닉네임 인사) |
| 라우터 | `AppRouter.createRouter(auth)` + `authRedirect` + `refreshListenable`, `/login`·`/my/profile/edit`, `_MovieLogRouterApp`에서 Router 한 번만 생성 |
| Challenge | `email_preferences.dart`(이메일만 저장) · 내 정보 로딩/재시도 · 가입일 · 뒤로가기 확인 Dialog |
| 심화 | `install_marker.dart` — 최초 설치 flag가 없으면 Keychain에 남은 토큰 삭제 |
| 삭제 | `learning_member_session.dart`(7주차 학습용 memberId) — 토큰이 사용자를 식별하므로 필요 없어짐 |

## v6 → v7 평점 계약 변화

| 동작 | v6 (7주차) | v7 (8주차) |
| --- | --- | --- |
| 등록 | `POST /v6/members/{memberId}/ratings` → 201, result 읽지 않음 | `POST /v7/ratings` → 201, **result = Rating** |
| 수정 | `PATCH /v6/members/{memberId}/ratings/{id}` → result null | `PATCH /v7/ratings/{id}` → **result = Rating** |
| 삭제 | 같은 memberId 포함 → **204** 본문 없음 | `DELETE /v7/ratings/{id}` → **200** + result null |
| 사용자 식별 | path의 memberId | `Authorization: Bearer {MovieLog JWT}` |
| 오류 code | COMMON400/403/404/409 | RATING403_1 · RATING404_1 · RATING409_1 · MEMBER404_1 · AUTH401_2/3/4 |
| 목록 | 서버 GET으로 다시 조회 | 토큰 기반 목록 GET 없음 → 이번 세션의 등록 result를 보관·갱신 |

## 설계에서 고른 것

- **토큰이 있다고 signedIn이 아니다** — 재시작 시 저장소에서 토큰을 읽고 GET me 성공 뒤에만 signedIn. 네트워크 실패는 retryRequired(토큰 유지), AUTH401_2/3/4만 세션 정리.
- **신규 로그인은 토큰 저장 → signedIn → MainScreen.loadMember()** — 로그인 함수에 GET me를 중복으로 넣지 않는다. 탭 Shell(MainScreen)에서 부르므로 어느 탭으로 들어와도 member가 채워진다.
- **화면 이동은 Router 한 곳** — 로그인·로그아웃·만료 모두 상태만 바꾸고, `redirect`가 `/start`·`/login`·`/home`을 정한다. 로그인 화면은 `context.go('/home')`을 하지 않는다.
- **401 세 종류를 섞지 않는다** — 로그인 AUTH401_1은 Form 문구, 보호 요청 AUTH401_2/3/4는 세션 정리 + 만료 Snackbar, 403은 안내만.
- **`expireSession(requestVersion)`** — 요청을 보낼 때의 sessionVersion을 넘긴다. 동시에 온 401 여러 개는 첫 번째만 처리하고, 이전 세션의 늦은 401은 새 로그인을 지우지 못한다.
- **두 Authorization을 섞지 않는다** — TMDB Client와 워크북 Client는 끝까지 따로. AuthInterceptor는 보호용 Client에만 있고, 그 안에서도 `workbook.devnoco.com`의 보호 경로에만 붙인다.
- **로그에도 토큰을 남기지 않는다** — Header는 `Bearer ***`, 로그인 응답 Body의 accessToken도 `***`. (트러블슈팅 4)
- **memberId를 추정하지 않는다** — JWT payload를 열어 memberId를 꺼내지 않았다. 대신 "이번 로그인에서 등록한 평점"으로 범위를 분명히 했다.

## 보안 저장 검증 (iOS 시뮬레이터)

| 확인 | 결과 |
| --- | --- |
| 평문 설정(`Library/Preferences/com.example.movielog.plist`) | `movielog.install_initialized: true`, `movielog.saved_email: ***@naver.com` 두 개뿐 — **토큰 없음** |
| 앱 컨테이너 전체에서 `access_token` 문자열 검색 | 없음 |
| 시뮬레이터 Keychain DB(`keychain-2-debug.db`, genp 테이블) | 접근 그룹 `…com.example.movielog` 항목 1건, 생성 시각 22:05:21(로그인 시각), 값은 암호화 — 값은 읽지 않음 |
| 앱 종료 → 다시 실행 | 로그인 요청 없이 첫 요청이 `GET /v7/members/me`(Bearer ***) 200 → 홈 "태이님" |
| 재빌드·재설치(flutter run) 후 | Keychain 토큰 유지 → 세션 복원 |
| (심화) 최초 설치 flag | 첫 실행 직후 `install_initialized: true` 기록 확인. **실제 앱 삭제 후 재설치 시나리오는 검증하지 않음** |
| Android | 검증하지 않음 |

## 실행 화면

iOS는 시뮬레이터, 나머지는 Chrome에서 393×604 크기의 같은 출처 iframe으로 찍었다. 개인 이메일은 회색 상자로 가렸다.

| 번호 | 파일 | 내용 |
| --- | --- | --- |
| 01 | `week8-01-ios-login-400-email-format.png` | 이메일 형식 오류 → 서버 COMMON400 문구 |
| 02 | `week8-02-ios-login-401-wrong-account.png` | 없는 계정 → AUTH401_1, Form 문구만 (만료 처리 없음) |
| 03 | `week8-03-ios-signup-to-login-stale-message.png` | 가입 후 로그인 화면(이메일 채움) — 이전 문구가 남던 버그 (트러블슈팅 2) |
| 04 | `week8-04-ios-login-success-home.png` | 로그인 성공 → 홈 |
| 05 | `week8-05-home-nickname.png` | 홈 인사말에 GET me 닉네임 |
| 06 | `week8-06-mypage-me.png` | 마이페이지: 닉네임·가입일(Challenge)·이메일, 앱바 로그아웃 |
| 07 | `week8-07-profile-edit.png` | 프로필 수정: 이메일 읽기 전용, 닉네임만 편집 |
| 08 | `week8-08-profile-409-duplicate.png` | MEMBER409_1 → 필드 아래 오류, 입력값 유지 |
| 09 | `week8-09-profile-400-length.png` | 1자 → 요청 전 2~12자 검증 |
| 10 | `week8-10-profile-back-confirm.png` | 변경 후 뒤로가기 → 확인 Dialog (Challenge) |
| 11 | `week8-11-profile-saved.png` | 저장 성공 → 마이페이지 복귀 + Snackbar |
| 12 | `week8-12-mypage-updated.png` | 새 닉네임 즉시 반영 (GET me 재호출 없음) |
| 13~15 | `week8-13-detail-before.png` ~ `week8-15-rating-created.png` | 상세 → 별 4개·코멘트 → POST /v7/ratings 201 → "내 평점 4.0" |
| 16 | `week8-16-rating-409.png` | 재시작 후 같은 영화 재등록 → RATING409_1, Dialog 유지 |
| 17 | `week8-17-my-ratings-session.png` | 이번 로그인에서 등록한 평점 |
| 18~20 | `week8-18-edit-prefilled.png` ~ `week8-20-edit-saved.png` | 기존 값 채운 수정 Dialog → PATCH result로 카드 갱신 |
| 21~22 | `week8-21-delete-confirm.png`, `week8-22-delete-success-empty.png` | 삭제 확인 → DELETE 200 → Empty |
| 23~24 | `week8-23-expiry-before.png`, `week8-24-expiry-login-snackbar.png` | 무효 토큰 AUTH401_3 → 세션 정리 → /login + 만료 Snackbar (이메일 저장으로 이메일 채움) |
| 25~27 | `week8-25-logout-button.png` ~ `week8-27-protected-redirect.png` | 로그아웃 → /login(만료 Snackbar 없음) → `/my` 직접 이동 시 /login으로 차단 |

GIF: `week8-gif-ios-restart-restore.gif`(재시작 → 세션 복원 → 홈) · `week8-gif-profile-edit.gif` · `week8-gif-rating-crud.gif` · `week8-gif-expiry.gif` · `week8-gif-logout-redirect.gif`

## 401 / 403 / 409 처리

| code | 어디서 | 처리 | 실서버 확인 |
| --- | --- | --- | --- |
| AUTH401_1 | 로그인 | Form 문구, signedOut 유지, 만료 표시 없음 | ✅ iOS (02) |
| AUTH401_3 | 보호 요청(PATCH me) | `expireSession` → 토큰 삭제 → /login + Snackbar 1회 | ✅ 웹 (23·24) — 브라우저에서 내 요청 1건의 Authorization 값만 무효 문자열로 바꿔 재현 |
| AUTH401_2/4 | 보호 요청 | 같은 처리 | 테스트 (토큰 없음/만료는 실제로 만들기 어려움) |
| RATING403_1 | 남의 평점 수정·삭제 | Dialog 안내만, 로그인 유지 | **테스트만** — 실서버 재현은 다른 회원의 평점에 수정 요청을 보내야 해서 하지 않았다 |
| RATING409_1 | 같은 영화 재등록 | Dialog 안내, 입력 유지, 로그인 유지 | ✅ 웹 (16) |
| MEMBER409_1 | 닉네임 중복 | 필드 오류, 입력 유지 | ✅ 웹 (08) |

## 남은 한계

- **재시작 뒤 내 평점 전체 복원은 완료 기능이 아니다.** v7에 토큰 기반 내 평점 목록 GET이 없고, 로그인·내 정보 응답에 memberId가 없다. 계약이 확인되면 SessionRatingStore 대신 서버 목록으로 바꾼다.
- 로그아웃은 클라이언트 세션만 비운다. 서버에서 토큰이 즉시 폐기된다고 보장하지 않는다.
- Android secure storage와 iOS 실제 재설치 시나리오는 검증하지 않았다.

## 학습 회고

(공부 후 작성)
