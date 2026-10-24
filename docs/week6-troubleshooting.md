# 6주차 트러블슈팅 (Frontend)

워크북 템플릿(작업 / 요청 Method·Path / 입력값 / 기대한 상태 / 실제 상태 및 응답 / 원인 / 수정 / 재검증) 그대로 적었다.

## 1. 통신 중 상태를 확인하는 테스트가 엉뚱한 버튼을 검사함

```
작업: 닉네임 확인
요청 Method·Path: GET /v5/members/nickname/{nickname} (테스트에서는 FakeMemberCheckService가 응답을 붙잡아 둠)
입력값(민감 정보 제거): 닉네임 "태이"
기대한 상태: 닉네임 옆 버튼 isLoading == true
실제 상태 및 응답: Expected: true / Actual: false
원인: 버튼을 find.widgetWithText(MovieLogButton, '중복 확인').at(0)으로 찾았다.
      통신 중에는 label 대신 인디케이터만 그리므로 닉네임 버튼에서 '중복 확인' 글자가 사라지고,
      .at(0)이 이메일 버튼을 가리키게 됐다.
수정: 글자 대신 순서로 찾는다. find.byType(MovieLogButton).at(0) = 닉네임, at(1) = 이메일
재검증: flutter test → 통신 중 isLoading true, ElevatedButton.onPressed null, 인디케이터 1개 확인
```

배운 점: "label과 인디케이터를 동시에 그리지 않는다"는 규칙이 실제로 지켜지고 있다는 증거이기도 했다.

## 2. 가입하기 버튼(width: double.infinity)이 화면 너비보다 좁음

```
작업: MovieLogButton 너비 확인
요청 Method·Path: 없음 (레이아웃)
입력값(민감 정보 제거): 테스트 화면 너비 800
기대한 상태: 가입하기 버튼 너비 = 화면 너비 - 좌우 패딩 48 = 752
실제 상태 및 응답: Expected: 752.0 / Actual: 512.0
원인: 회원가입 Form은 2주차에 "넓은 화면이면 최대 560"으로 ConstrainedBox를 씌워 두었다.
      double.infinity는 "화면 전체"가 아니라 "부모가 허용하는 최대 너비"라서 560 - 패딩 48 = 512가 맞다.
수정: 테스트 기준을 화면 너비가 아니라 Form 너비로 바꿨다.
재검증: 가입하기 너비 == Form 너비, 중복 확인 버튼(width null)은 Form 너비의 1/3 미만
```

## 3. 통신 실패 문구가 "다시 시도해 …"로 잘림

```
작업: 닉네임 확인 (통신 실패)
요청 Method·Path: GET /v5/members/nickname/%ED%83%9C%EC%9D%B4 (캡처 도구에서 요청을 강제로 끊음)
입력값(민감 정보 제거): 닉네임 "태이"
기대한 상태: error 상태, "중복 확인에 실패했습니다. 다시 시도해 주세요." 전체 표시
실제 상태 및 응답: 상태는 error가 맞지만 문구가 "다시 시도해 …"에서 잘림
원인: 입력창 옆에 버튼을 나란히 두면서 입력창 폭이 좁아졌다. InputDecoration의 errorText는 기본 1줄이다.
수정: MovieLogTextFormField의 InputDecoration에 errorMaxLines: 2 추가
재검증: docs/week6-07-signup-error-vs-duplicated.png — 두 줄로 전부 보인다.
```

## 4. Loading 화면을 캡처하려고 응답을 붙잡았더니 10초 뒤 Error로 바뀜

```
작업: 내 평점 조회
요청 Method·Path: GET /v5/members/1/ratings
입력값(민감 정보 제거): memberId 1
기대한 상태: loading (인디케이터)
실제 상태 및 응답: error, "평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
원인: 캡처 스크립트가 페이지 로딩이 끝나기를(networkidle) 기다렸는데, 붙잡아 둔 요청 때문에 끝나지 않았다.
      그 사이 Dio의 receiveTimeout(10초)이 지나 DioException(timeout)이 났고, ViewModel이 Error로 바꿨다.
수정: 화면이 뜨자마자(domcontentloaded) 캡처하도록 바꿨다.
재검증: docs/week6-12-ratings-loading.png
```

배운 점: 서버가 응답을 안 주는 상황도 Timeout을 걸어 두면 결국 Error 상태로 끝난다.
Timeout이 없으면 사용자는 무한 Loading을 보게 된다.

## 5. Empty·404 캡처에 "memberId 1"이 찍힘

```
작업: 내 평점 조회 (Empty / 404)
요청 Method·Path: GET /v5/members/3/ratings → [] , GET /v5/members/4/ratings → 404
입력값(민감 정보 제거): memberId 3, 4
기대한 상태: Empty / Error("존재하지 않는 회원입니다.")
실제 상태 및 응답: 상태는 맞지만 안내 문구가 "memberId 1 …"
원인: 처음에는 캡처 도구에서 요청 URL만 1 → 3, 4로 바꿔 보냈다. 앱은 여전히 memberId 1을 조회한다고 알고 있다.
수정: memberId는 상수로 두되, 디버그 실행에서만 --dart-define=SAMPLE_MEMBER_ID=3 으로 바꿀 수 있게 했다.
      (화면에 입력창은 만들지 않는다. 기본값은 1)
재검증: docs/week6-13-ratings-empty.png ("memberId 3"), docs/week6-14-ratings-error-404.png ("memberId 4")
```
