# 2주차 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | (PR 생성 후 채움) |
| 입력 전 화면 | `docs/week2-01-empty.png` |
| Validation 오류 화면 | `docs/week2-02-error.png` |
| 입력 완료 화면 | `docs/week2-03-complete.png` |
| 키보드 열린 화면 | `docs/week2-04-keyboard.png` — 이메일 키보드(`@` 키), 하단 Overflow 없음 |
| 평점 선택 화면 | 미제출 — 워크북에 `flutter_rating_bar` 미니 실습 본문이 없어 운영진 확인 후 추가 예정 |
| 넓은 화면 Challenge — 선택 | `docs/week2-05-wide.png` — iPad Pro 13", Form 최대 너비 560, 상단 가운데 정렬 |
| Validator 규칙 | 닉네임: 빈 값 → "닉네임을 입력해주세요." / trim 후 2글자 미만 → "닉네임은 두 글자 이상 입력해주세요." <br> 이메일: 빈 값 → "이메일을 입력해주세요." / `^[^@\s]+@[^@\s]+\.[^@\s]+$` 불일치 → "올바른 이메일 형식이 아닙니다." <br> 비밀번호: 빈 값 → "비밀번호를 입력해주세요." / 8자 미만 → "비밀번호는 8자 이상 입력해주세요." |
| 버튼 활성화 조건 (`canSubmit`) | 닉네임 trim 2글자 이상 && 이메일 `@` 포함 && 비밀번호 8자 이상 && 약관 동의. Validator보다 느슨하게 두고, 버튼을 누르면 `validate()`로 최종 검증 |
| 선택한 평점 | — (미니 실습 미제출) |
| dispose한 객체 | `_nicknameController`, `_emailController`, `_passwordController`, `_emailFocusNode`, `_passwordFocusNode` (5개, `super.dispose()` 마지막 호출) |
| 사용한 반응형 기준 | `LayoutBuilder`의 `constraints.maxWidth >= 700`이면 `ConstrainedBox(maxWidth: 560)` + `Align(topCenter)`, 미만이면 `double.infinity`. `MediaQuery`가 아니라 부모가 실제로 준 너비를 기준으로 분기 |
| 분리한 Widget | `MovieLogTextFormField`(입력창 공통, Challenge 겸용), `TermsCheckbox`, `SignUpButton` — Controller·FocusNode·상태는 전부 `_SignUpScreenState`가 소유하고 자식은 받아서 연결만 함 |
| Challenge | 비밀번호 표시·숨김(`_obscurePassword` + `suffixIcon` IconButton), 공통 `MovieLogTextFormField`, 넓은 화면 레이아웃 — 3개 모두 구현 |
| 트러블슈팅 | `docs/week2-troubleshooting.md` (4건) |

## 화면 구조

```
SignUpScreen (StatefulWidget)
 └ Scaffold
    ├ appBar: CommonAppBar('회원가입')
    └ body: SafeArea
       └ LayoutBuilder (constraints.maxWidth >= 700 ? 560 : infinity)
          └ Align (topCenter)
             └ ConstrainedBox (maxWidth)
                └ SingleChildScrollView (padding 24, onDrag로 키보드 닫기)
                   └ Form (_formKey)
                      └ Column (stretch)
                         ├ MovieLogTextFormField 닉네임  → next → _emailFocusNode
                         ├ MovieLogTextFormField 이메일  → next → _passwordFocusNode
                         ├ MovieLogTextFormField 비밀번호 → done → unfocus
                         │   └ suffixIcon: 👁 토글 (_obscurePassword)
                         ├ TermsCheckbox (_agreedToTerms)
                         └ SignUpButton (canSubmit ? _submit : null)
```

## 상태 흐름

```
사용자 입력 → onChanged → setState(() {}) → build 재호출
                                              ├ canSubmit 재계산 → 버튼 활성/비활성
                                              └ Controller.text는 자동 동기화 (setState 불필요)

가입 버튼 → _submit()
             ├ _formKey.currentState.validate()  → 각 validator 실행, 문자열 반환 시 오류 표시
             ├ 실패 → return
             ├ FocusScope.unfocus()               → 키보드 닫기
             └ SnackBar '○○님, 가입을 환영합니다!'
```

## 학습 회고

(학습 질문 세트에 답한 뒤 채운다)

### Expanded vs Flexible

### MediaQuery vs LayoutBuilder

### Form·TextFormField·Validator

### Controller·FocusNode 생명주기

### setState와 버튼 활성화

### 다음 주차로 넘어가며
