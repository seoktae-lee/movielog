# 7주차 트러블슈팅 (Frontend)

워크북 템플릿(작업 / 요청 Method·Path / 요청 body / 기대 status·body / 실제 status·code·message / 화면 상태 / 원인과 수정 / 재검증) 그대로 적었다.
비밀번호는 모두 `***`로 지웠다.

## 1. 중복 확인을 통과했는데 최종 가입이 409 — 그런데 이메일 칸에는 체크 표시가 남아 있음

```
작업: 회원가입
요청 Method·Path(비밀번호 제거): POST /v6/members
요청 body(민감 정보 제거): { email: "taei.w7.ecyy@movielog.dev", password: "***", nickname: "태이w7ecyy" }
기대 status·body: 201 + result.memberId
실제 status·code·message: 409 / COMMON409 / "이미 사용 중인 이메일입니다."
화면 상태: Snackbar는 떴지만 이메일 칸은 여전히 "사용할 수 있는 이메일입니다" + 체크 표시,
          가입하기 버튼도 보라색(활성) 그대로. 다시 누르면 같은 409가 반복된다.
원인과 수정: 중복 확인(GET)과 가입(POST) 사이에 다른 사용자가 같은 이메일로 먼저 가입했다.
          (캡처 스크립트로 실제 서버에 먼저 가입시켜 재현) 화면은 GET 결과(available)만 믿고 있었다.
          → 409 message에 "이메일"/"닉네임"이 들어 있으면 그 칸을 duplicated로 되돌린다.
            (DuplicateCheckField.markDuplicated) Snackbar는 그대로 보여 준다.
재검증: 409 직후 이메일 칸이 "이미 가입된 이메일입니다." 에러, 가입하기 비활성 (week7-02).
       이메일을 바꾸면 idle로 돌아가 다시 확인할 수 있다 (week7-03).
       테스트 "최종 409 이메일 중복이면 이메일 칸의 확인 결과도 duplicated로 되돌린다" 추가.
```

배운 점: 중복 확인 GET은 "그 순간"의 결과일 뿐이다. 최종 판단은 POST의 409이고, 화면 상태도 거기에 맞춰야 한다.

## 2. 서버의 비밀번호 400을 화면에서 재현할 수 없음

```
작업: 회원가입 (비밀번호 형식 오류)
요청 Method·Path(비밀번호 제거): POST /v6/members
요청 body(민감 정보 제거): password만 규칙 위반
기대 status·body: 400 / COMMON400 / "비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다."
실제 status·code·message: 요청이 아예 안 나감
화면 상태: 비밀번호 칸 아래 로컬 validator 문구 "대문자·소문자·숫자·특수문자(!@#$%^&*)를 각각 하나 이상 넣어 주세요."
원인과 수정: 클라이언트 validator를 서버 정규식과 똑같이 만들어서 정상 입력으로는 400이 나올 수 없다. (의도한 동작)
          서버 400 → passwordErrorText 연결을 확인하려고, 캡처 도구에서 POST body의 password만
          한 번 약한 값으로 바꿔 **실제 서버**로 보냈다. 앱 코드는 바꾸지 않았다.
재검증: 400 응답의 message가 비밀번호 칸 errorText로 보이고 Snackbar는 뜨지 않음 (week7-04).
       비밀번호를 다시 입력하면 onPasswordChanged가 에러를 지운다.
```

## 3. 회원가입 Widget 테스트 5개가 "No GoRouter found in context"로 실패

```
작업: 회원가입 제출 중 이탈 막기 (Challenge)
요청 Method·Path(비밀번호 제거): 없음 (Widget 테스트)
요청 body(민감 정보 제거): 없음
기대 status·body: 기존 회원가입 화면 테스트 통과
실제 status·code·message: FlutterError "No GoRouter found in context" (GoRouterHelper.canPop)
화면 상태: 테스트가 MaterialApp(home: SignUpScreen)으로 화면만 띄우는데 build에서 터짐
원인과 수정: AppBar 뒤로가기를 막으려고 build 안에서 context.canPop()(go_router 확장)을 불렀다.
          GoRouter 없이 띄운 화면에서는 찾을 수 없다.
          → Navigator.canPop(context) / Navigator.maybePop(context)로 바꿨다.
            maybePop은 PopScope(canPop: !isSubmitting)를 존중하므로 제출 중에는 AppBar 버튼으로도 못 나간다.
재검증: flutter test 전체 통과
```

## 4. "저장 중에는 Dialog가 닫히지 않는다" 테스트에서 PopScope.canPop이 true

```
작업: 평점 등록 (저장 중 이탈 막기)
요청 Method·Path(비밀번호 제거): POST /v6/members/42/ratings (Fake Service가 응답을 붙잡음)
요청 body(민감 정보 제거): { movieId: 550, score: 5 }
기대 status·body: 확인을 누른 직후 PopScope.canPop == false
실제 status·code·message: Expected: false / Actual: true
화면 상태: 확인을 눌렀는데 요청이 0번
원인과 수정: 별을 누른 뒤 pump 없이 바로 확인을 눌렀다. 별점 setState가 아직 화면에 반영되지 않아
          확인 버튼이 여전히 비활성(onPressed: null) → 탭이 무시됐다.
          (앱 버그가 아니라 "별점을 골라야 확인이 켜진다"는 규칙이 그대로 동작한 것)
          → 별 탭 뒤 tester.pump() 추가
재검증: 저장 중 canPop false, 바깥 탭으로 닫히지 않음, 응답을 풀면 Dialog가 닫힘
```

## 5. 다중 삭제 테스트: pumpAndSettle이 끝나지 않음 / 확인 Dialog가 남아 있음

```
작업: 다중 삭제 (Challenge)
요청 Method·Path(비밀번호 제거): DELETE /v6/members/42/ratings/{id} (Fake가 첫 요청을 붙잡음)
요청 body(민감 정보 제거): 없음
기대 status·body: 확인 Dialog는 닫히고 화면 위에 로딩 오버레이
실제 status·code·message: find.byType(AlertDialog) → Found 1 widget
화면 상태: Dialog가 닫히는 애니메이션 중간
원인과 수정: 오버레이의 CircularProgressIndicator가 계속 돌아서 pumpAndSettle은 영원히 끝나지 않는다.
          그래서 pump()만 두 번 했는데, 0초짜리 pump로는 Dialog 닫힘 애니메이션이 끝나지 않는다.
          → pump(const Duration(milliseconds: 400))로 애니메이션 시간만큼 진행
재검증: Dialog 없음 + ModalBarrier + 인디케이터 1개 확인, 응답을 풀면 [3, 1] 순서로 삭제
```

## 6. 캡처 중 이메일을 바꿨는데 "올바른 이메일 형식이 아닙니다."

```
작업: 회원가입 캡처 (입력 변경 무효화)
요청 Method·Path(비밀번호 제거): GET /v6/members/email/{email} — 요청이 나가지 않음
요청 body(민감 정보 제거): 없음
기대 status·body: 새 이메일로 200 {available:true}
실제 status·code·message: 요청 없음
화면 상태: 이메일 칸 빨간 테두리 + "올바른 이메일 형식이 아닙니다."
원인과 수정: 캡처 스크립트가 Cmd+A → Backspace로 칸을 비우려 했는데, Flutter 웹의 편집용 input에는 먹지 않아
          기존 이메일 뒤에 새 이메일이 이어 붙었다("…@movielog.devtaei…").
          앱의 validator는 제대로 동작한 것.
          → 포커스된 편집 요소의 value를 비우고 input 이벤트를 보내도록 스크립트를 고쳤다.
재검증: 새 이메일로 중복 확인 200, 이후 400 → 201까지 진행 (week7-03~06)
```
