# 8주차 서버 요청 기록 (Frontend)

앱의 디버그 로그(`ApiLoggingInterceptor`)를 그대로 옮겼다. 2026-11-09, 실제 워크북 서버(v7) 상대.

- `Authorization` Header는 로그 단계에서 `Bearer ***`로 가린다. (원문 토큰은 로그·문서·캡처 어디에도 없다)
- 로그인 응답 Body의 `accessToken`도 `***`로 가린다. (8주차에 추가한 `maskBody`)
- 비밀번호는 요청 Body를 로그로 찍지 않으므로 남지 않는다.
- 아래 문서에서는 개인 이메일을 `***@naver.com`으로 바꿔 적었다.
- `[MovieLog 요청]`은 공개용 Client(Interceptor 없음), `[MovieLog 보호 요청]`은 보호용 Client(AuthInterceptor)다.

## iOS 시뮬레이터 (iPhone 18 Pro, iOS 27.0)

### 로그인 실패 — 이메일 형식 (COMMON400)
[MovieLog 요청] POST https://workbook.devnoco.com/v7/auth/login
[MovieLog 오류 Body] {isSuccess: false, code: COMMON400, message: 이메일 형식이 올바르지 않습니다., result: null}

### 로그인 실패 — 계정 불일치 (AUTH401_1, 세션 만료 처리 안 함)
[MovieLog 요청] POST https://workbook.devnoco.com/v7/auth/login
[MovieLog 오류 Body] {isSuccess: false, code: AUTH401_1, message: 이메일 또는 비밀번호가 올바르지 않습니다., result: null}

### 회원가입 → 로그인 → 내 정보 (MainScreen.loadMember)
[MovieLog 요청] POST https://workbook.devnoco.com/v7/members
[MovieLog 응답] 201 https://workbook.devnoco.com/v7/members
[MovieLog 요청] POST https://workbook.devnoco.com/v7/auth/login
[MovieLog 응답] 200 https://workbook.devnoco.com/v7/auth/login
[MovieLog 응답 Body] {isSuccess: true, code: COMMON200, message: 로그인에 성공했습니다., result: {nickname: 태이, accessToken: ***}}
[MovieLog 보호 요청] GET https://workbook.devnoco.com/v7/members/me
[MovieLog 보호 요청 Header] {Authorization: Bearer ***}
[MovieLog 보호 응답] 200 https://workbook.devnoco.com/v7/members/me

### 앱 재시작 → 세션 복원 (로그인 요청 없이 첫 요청이 GET me)
[MovieLog 보호 요청] GET https://workbook.devnoco.com/v7/members/me
[MovieLog 보호 요청 Header] {Authorization: Bearer ***}
[MovieLog 보호 응답] 200 https://workbook.devnoco.com/v7/members/me
[MovieLog 보호 응답 Body] {isSuccess: true, code: COMMON200, message: 회원 정보를 조회했습니다., result: {email: ***@naver.com, nickname: 태이, createdAt: 2026-11-09T13:04:32.358Z}}
[TMDB 요청 Header] {Authorization: Bearer ***, accept: application/json}   ← TMDB는 별도 Client, 별도 Token

## Chrome (Flutter web debug, 같은 출처 iframe 393×604)

### 평점 등록 (POST /v7/ratings) — 23:03:28
[MovieLog 보호 요청] POST https://workbook.devnoco.com/v7/ratings
[MovieLog 보호 요청 Header] {content-type: application/json, Authorization: Bearer ***}
[MovieLog 보호 응답] 201 https://workbook.devnoco.com/v7/ratings
[MovieLog 보호 응답 Body] {isSuccess: true, code: COMMON201, message: 평점을 등록했습니다., result: {ratingId: 57, movieId: 155, score: 4, comment: 조커가 다 했다, createdAt: 2026-11-09T14:03:28.754Z, updatedAt: 2026-11-09T14:03:28.754Z}}

### 같은 영화 재등록 409 (앱 재시작 뒤, RATING409_1) — 23:04:04
[MovieLog 보호 요청] POST https://workbook.devnoco.com/v7/ratings
[MovieLog 보호 오류 Header] {content-type: application/json, Authorization: Bearer ***}
[MovieLog 보호 오류 내용] badResponse / status 409
[MovieLog 보호 오류 Body] {isSuccess: false, code: RATING409_1, message: 이미 이 영화에 평점을 남기셨습니다., result: null}

### 평점 수정 (PATCH /v7/ratings/58) — 23:05:00
[MovieLog 보호 요청] PATCH https://workbook.devnoco.com/v7/ratings/58
[MovieLog 보호 요청 Header] {content-type: application/json, Authorization: Bearer ***}
[MovieLog 보호 응답] 200 https://workbook.devnoco.com/v7/ratings/58
[MovieLog 보호 응답 Body] {isSuccess: true, code: COMMON200, message: 평점을 수정했습니다., result: {ratingId: 58, movieId: 687163, score: 3, comment: 두 번째 보니 길다, createdAt: 2026-11-09T14:04:35.820Z, updatedAt: 2026-11-09T14:05:00.000Z}}

### 평점 삭제 (DELETE /v7/ratings/59, 성공 200 + result null) — 23:06:35
[MovieLog 보호 요청] DELETE https://workbook.devnoco.com/v7/ratings/59
[MovieLog 보호 요청 Header] {Authorization: Bearer ***}
[MovieLog 보호 응답] 200 https://workbook.devnoco.com/v7/ratings/59
[MovieLog 보호 응답 Body] {isSuccess: true, code: COMMON200, message: 평점을 삭제했습니다., result: null}

### 세션 만료 재현 (무효 토큰 → AUTH401_3 → 세션 정리 → /login + Snackbar) — 23:07:13
재현 방법: 브라우저에서 내 앱의 다음 보호 요청 1건만 Authorization 값을 무효 문자열로 바꿔 보냈다. (실제 토큰 원문은 다루지 않음)
[MovieLog 보호 요청] PATCH https://workbook.devnoco.com/v7/members/me
[MovieLog 보호 요청 Header] {content-type: application/json, Authorization: Bearer ***}
[MovieLog 보호 오류 내용] badResponse / status 401
[MovieLog 보호 오류 Body] {isSuccess: false, code: AUTH401_3, message: 유효하지 않은 토큰입니다., result: null}

