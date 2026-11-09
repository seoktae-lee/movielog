# 8주차 트러블슈팅 (Frontend)

워크북의 트러블슈팅 양식(인증 상태·요청 종류·status/code·예상/실제 AuthStatus·원인·수정·재검증)을 따른다.
토큰과 비밀번호는 어디에도 적지 않았다.

## 1. 프로필 저장은 성공했는데 화면이 닫히지 않음

```
인증 상태와 재현 순서: signedIn → 마이페이지 → 프로필 수정 → 닉네임 변경 → 저장
요청 종류(로그인/공개/보호): 보호 (PATCH /v7/members/me)
status·code(토큰/비밀번호 제거): 200 COMMON200
예상한 AuthStatus: signedIn 유지, 마이페이지로 pop
실제 AuthStatus/화면: signedIn, "프로필을 수정했어요." Snackbar는 떴지만 프로필 수정 화면에 그대로 머묾
원인: PopScope는 마지막으로 그려진 canPop 값을 쓴다. 저장 직후에는 아직 "저장 중·변경 있음"(canPop false)으로
      그려진 상태였고, 그 프레임의 onPopInvoked 콜백도 saving=true를 캡처하고 있어 확인 Dialog조차 뜨지 않았다.
수정: _leaving을 setState로 반영해 canPop=true로 다시 그린 다음 프레임(addPostFrameCallback)에 pop한다.
      "나가기" 확인 Dialog 경로도 같은 함수(_leave)를 쓴다.
재시작·로그아웃·회원 전환 재검증: 웹에서 저장 → 마이페이지 복귀·새 닉네임 즉시 반영 확인.
      Widget 테스트 "저장에 성공하면 마이페이지로 돌아가고…"를 추가했고, 고치기 전 코드로 돌리면
      Expected '/my' / Actual '/my/profile/edit'로 실패하는 것까지 확인했다.
```

## 2. 회원가입을 마치고 돌아온 로그인 화면에 이전 실패 문구가 남음

```
인증 상태와 재현 순서: signedOut → 틀린 계정으로 로그인(AUTH401_1) → 회원가입 → 가입 성공 → /login
요청 종류: 공개 (POST /v7/auth/login → POST /v7/members)
status·code: 401 AUTH401_1 → 201 COMMON201
예상한 AuthStatus: signedOut, 깨끗한 로그인 Form + 가입한 이메일
실제 AuthStatus/화면: signedOut, 이메일은 채워졌지만 "이메일 또는 비밀번호를 확인해 주세요."가 그대로 (week8-03)
원인: 실패 문구는 AuthViewModel.message에 있고, 가입은 AuthViewModel을 거치지 않아 아무도 지우지 않았다.
수정: AuthViewModel.clearMessage() 추가. LoginScreen.didUpdateWidget에서 새 이메일이 넘어오면 프레임 뒤에 호출.
재시작·로그아웃·회원 전환 재검증: 가입 직후 화면에서 문구가 사라지는 것 확인(핫 리로드 후 다음 가입부터 적용).
```

## 3. `go('/login', extra: email)`로 돌아왔는데 이메일 칸이 비어 있음

```
인증 상태와 재현 순서: signedOut → 로그인 화면 → 회원가입(push) → 가입 성공 → go('/login', extra: 이메일)
요청 종류: 공개 (POST /v7/members)
status·code: 201
예상한 AuthStatus: signedOut, 이메일 채워진 로그인 화면
실제 AuthStatus/화면: 이메일 칸이 비어 있음 (Widget 테스트에서 발견)
원인: /login 페이지가 이미 스택 아래에 있어서 GoRouter가 같은 State를 재사용했다. initState가 다시 불리지 않아
      initialEmail을 읽는 코드가 실행되지 않았다.
수정: didUpdateWidget에서 initialEmail이 바뀌면 이메일을 채우고 비밀번호 칸을 비운다.
재시작·로그아웃·회원 전환 재검증: iOS 실기기 흐름에서 가입 후 이메일이 채워진 것 확인 (week8-03).
```

## 4. 로그인 응답 Body로 JWT 원문이 콘솔에 찍힐 뻔함

```
인증 상태와 재현 순서: signedOut → 로그인 성공
요청 종류: 공개 (POST /v7/auth/login)
status·code: 200 COMMON200
예상한 AuthStatus: signedIn, 콘솔에 토큰 원문 없음
실제 AuthStatus/화면: (구현 중 코드 검토로 발견) 5주차부터 쓰던 ApiLoggingInterceptor가 Header의 Authorization만 가리고
      응답 Body는 그대로 출력한다. 로그인 result에 accessToken이 들어 있으므로 원문이 콘솔에 남는다.
원인: "토큰은 Header에만 있다"는 가정. 로그인 응답은 토큰이 Body로 오는 유일한 응답이다.
수정: ApiLoggingInterceptor.maskBody — Body 문자열의 accessToken 값을 ***로 바꾼다. 테스트 추가.
재시작·로그아웃·회원 전환 재검증: iOS 로그에서 `result: {nickname: 태이, accessToken: ***}` 확인 (week8-network-log.md).
```

## 5. Widget 테스트 전체가 "SharedPreferencesAsyncPlatform instance must be set"으로 실패

```
인증 상태와 재현 순서: 테스트에서 MovieLogApp을 띄움 (가짜 EmailPreferences·InstallMarker 주입)
요청 종류: 없음 (앱 생성 단계)
status·code: StateError
예상한 AuthStatus: initializing → signedIn
실제 AuthStatus/화면: build에서 예외, 30개 테스트 실패
원인: MovieLogApp.build가 주입 여부와 상관없이 SharedPreferencesAsync()를 먼저 만들었다. 테스트 환경에는 플랫폼 구현이 없다.
수정: 실제로 필요할 때만 만드는 함수(prefs())로 바꿔, 가짜를 주입하면 생성 자체를 하지 않게 했다.
재시작·로그아웃·회원 전환 재검증: 전체 테스트 144개 통과.
```

## 6. 재시작하면 "내가 등록한 평점"이 비고, 같은 영화를 다시 등록하면 409

```
인증 상태와 재현 순서: signedIn → 영화 155 평점 등록(ratingId 57) → 앱 새로고침(세션 복원) → 같은 영화 평점 남기기
요청 종류: 보호 (POST /v7/ratings)
status·code: 409 RATING409_1
예상한 AuthStatus: signedIn 유지, 409는 안내만
실제 AuthStatus/화면: signedIn 유지, Dialog 안에 "이미 이 영화에 평점을 남겼어요. 기존 기록을 확인해 주세요." (week8-16)
원인: 버그가 아니라 v7 계약의 한계다. 로그인·내 정보 응답에 memberId가 없고, 토큰 기반 "내 평점 목록 GET"도 없다.
      그래서 목록은 이번 세션에서 받은 등록 result(SessionRatingStore)만 보여 줄 수 있다.
수정: 코드 수정 없음. Empty 화면과 마이페이지 항목에 "이번 로그인에서 등록한 평점"·"앱을 다시 시작하면 이전 평점은
      표시되지 않아요 (v7 API 한계)"를 적어 기대를 맞췄다. JWT claim에서 memberId를 추정하지 않았다.
재시작·로그아웃·회원 전환 재검증: 로그아웃·만료 시 보관함이 비고, 이전 세션의 늦은 응답은 sessionVersion으로 버려진다
      (my_ratings_view_model_test "로그아웃 뒤 늦게 도착한 수정 응답은 반영하지 않는다").
```

## 7. 시뮬레이터 화면이 보이지 않음 / 재시작 영상에 옛 코드가 나옴

```
인증 상태와 재현 순서: signedIn(iOS) → simctl terminate → simctl launch
요청 종류: 보호 (GET /v7/members/me)
status·code: 200
예상한 AuthStatus: initializing → signedIn, 홈 인사말에 서버 닉네임
실제 AuthStatus/화면: 복원은 됐지만 인사말이 "무비러버님" (핫 리로드 이전 코드)
원인: (1) Xcode 27에는 Simulator.app이 없고 DeviceHub.app이 대신한다. (2) 핫 리로드는 실행 중인 VM에만 들어가고
      설치된 앱 번들은 바뀌지 않는다. simctl로 다시 켜면 처음 설치한 코드가 뜬다.
수정: flutter run으로 다시 빌드·설치한 뒤(Keychain 토큰은 그대로 남음) 재시작 영상을 다시 찍었다.
재시작·로그아웃·회원 전환 재검증: 재빌드 후 첫 MovieLog 요청이 로그인 없이 GET me 200 → "태이님" 홈 (week8-gif-ios-restart-restore).
```
