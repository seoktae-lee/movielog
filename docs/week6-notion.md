# 6주차 Frontend 노션 제출본 (원고)

> 노션 6주차 Frontend 페이지("6주차 - 중복 확인 연동과 평점 조회하기")에 붙여넣는 원고. 워크북 순서 그대로다.
> `🖼️` 표시 자리에 이미지를 드래그한다. **토글 안에 넣지 말 것** (채점에서 빠질 수 있음).

## 📌 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/8 |
| 브랜치 | `feature/week-6` |
| 사용 API | 워크북 Swagger v5 (`https://workbook.devnoco.com/v5`) + TMDB 상세 |
| 검증 | `flutter analyze` 0건 / `flutter test` 81개 통과 |

## 📸 스터디 인증

- [ ] 닉네임·이메일 확인 전 / 통신 중 / 사용 가능 / 중복 화면
  🖼️ `week6-01-signup-idle.png` · `week6-02-signup-checking.png` · `week6-03-signup-available.png` · `week6-04-signup-duplicated.png`
- [ ] 입력을 바꾸면 이전 확인 결과가 사라지는 화면
  🖼️ `week6-04-signup-duplicated.png` → `week6-05-signup-invalidated.png` ("영화광"에서 한 글자 지우자 에러가 사라지고 버튼이 다시 보라색)
- [ ] 중복된 문구를 그대로 다시 입력했을 때 즉시 에러로 바뀌는 화면
  🖼️ `week6-06-signup-same-again.png` ("광"을 다시 치자 서버 요청 0번으로 즉시 에러)
- [ ] MovieLogButton을 너비 다르게 배치한 화면
  🖼️ `week6-09-button-width.png` (null / 96 / double.infinity / Row 안 / 상태 3개) + `week6-08-signup-ready.png` (실제 화면: 중복 확인 = null, 가입하기 = infinity)
- [ ] 마이페이지 → 내가 등록한 평점(memberId 1) 진입
  🖼️ `week6-10-mypage-entry.png` → `week6-11-ratings-success.png`
- [ ] 내가 등록한 평점 Loading / Empty / Error / Success
  🖼️ `week6-12-ratings-loading.png` · `week6-13-ratings-empty.png` · `week6-14-ratings-error-404.png` · `week6-11-ratings-success.png`
- [ ] flutter analyze 결과와 수동 검증 결과, Pull Request 링크

```
$ flutter analyze
No issues found!

$ flutter test
+81: All tests passed!
```

## 🎯 핵심 개념

1. **v5는 공통 Wrapper가 없다** — 성공하면 결과값(`{ "available": true }`, 평점 배열)을 그대로, 실패하면 프레임워크 기본 형식(`message`, `error`, `statusCode`)을 준다. 그래서 `response.data`를 바로 `CheckResult.fromJson`에 넣는다. 공통 형식(`result`)은 v6부터라 이번 주 파싱과 구분해서 기억한다.
2. **공용 Button의 세 상태** — 기본(누를 수 있음) / 통신 중(`isLoading`: 회색 + 가운데 인디케이터만, 다시 못 누름) / 비활성(`onPressed: null`). 화면마다 따로 만들면 통신 중 표시를 빠뜨리는 화면이 생긴다.
3. **공용 Widget의 위치와 책임** — 특정 화면에 속하지 않으므로 `lib/widgets/`에 둔다. 상태를 "표시"만 하고 스스로 바꾸지 않는다. 지금 통신 중인지, 누를 수 있는지는 ViewModel이 정하고 View가 전달한다.
4. **width 세 가지** — `null`: 내용(Intrinsic) 크기, 입력창 옆 보조 버튼 / `double.infinity`: **부모가 허용하는** 최대 너비, Form 아래 제출 버튼 / 고정 값: 항상 같은 크기. `Row`처럼 가로 크기가 정해지지 않은 부모 안에서 infinity를 쓰면 오류이므로 `Expanded`로 감싼다.
5. **CheckStatus 하나에서 버튼·에러가 함께 나온다** — `idle / checking / available / duplicated / error`. `canCheck = checking도 duplicated도 아닐 때`, `errorText = duplicated·error일 때 문구`.
6. **통신 실패 ≠ 중복** — `available: false`는 서버가 정상 응답한 "중복"(duplicated), `DioException`은 통신 자체 실패(error). 문구도 다르고, error는 다시 누를 수 있다.
7. **입력이 바뀌면 이전 결과 무효화** — `onChanged`에서 idle로 되돌리고 `requestVersion++`. 기다리던 응답이 늦게 와도 버전·현재 입력값이 다르면 버린다.
8. **마지막으로 "중복"이었던 값 기억 (Challenge)** — "마지막으로 확인한 값"과 따로 둔다. 같은 문자열로 돌아오면 API 없이 즉시 duplicated. 단, 서버 상태는 바뀔 수 있으니 최종 기준은 회원가입 POST의 409다.
9. **validator와 errorText를 함께** — validator는 형식(2자 이상, 이메일 모양)만, 서버 중복 여부는 ViewModel의 errorText가 담당한다. 형식이 틀리면 서버에 묻지 않는다.
10. **화면마다 ViewModel 하나** — 회원가입 = `SignUpViewModel`, 내가 등록한 평점 = `MyRatingsViewModel`. Service(`MemberCheckService`, `RatingApiService`)는 상태가 없어서 앱 최상단 `MultiProvider`에 한 번 등록하고 `context.read`로 같이 쓴다.
11. **빈 배열은 실패가 아니다** — `[]` = Empty, `DioException`만 Error. 400(형식)·404(없는 회원)·그 밖(네트워크)을 `writeMyRatingsErrorMessage`로 다른 문구로 나눈다.
12. **평점은 자체 백엔드가 주인** — movieId로 TMDB 상세를 붙이되, TMDB에서 못 찾으면(404 → `findMovieById`가 null) 제목·포스터만 placeholder로 두고 평점은 남긴다. 같은 movieId는 캐시, 일시적 네트워크 실패는 캐시하지 않는다.
13. **parentNavigatorKey** — ShellRoute 안의 GoRoute는 기본으로 Shell의 Navigator에 쌓여 NavigationBar가 남는다. GoRouter에 root `navigatorKey`를 등록하고 `/my/ratings`에 같은 키를 `parentNavigatorKey`로 주면 root 위에 push돼 NavigationBar가 가려진다.
14. **TMDB Client와 워크북 Client는 분리** — baseUrl·Header가 다르다. 합치면 TMDB Token이 우리 서버로 나간다. 워크북 쪽 두 Service는 같은 백엔드라 Dio 하나를 공유한다.

## 🧪 Guided Practice A — 닉네임 중복 확인 버튼

1. `MemberCheckService.checkNickname`으로 v5 API 직접 호출 → `{"available":true}` / "영화광"은 `{"available":false}` 확인
2. `MovieLogButton` 작성, `isLoading`·`onPressed`·`width`를 바꿔 모양 확인 🖼️ `week6-09-button-width.png`
3. `SignUpViewModel`에 `nicknameCheckStatus`와 `checkNickname`

직접 완성할 영역:
- [x] `TextFormField.errorText` ← `viewModel.nicknameErrorText`
- [x] `onChanged` → `onNicknameChanged`로 이전 결과 idle
- [x] 이메일도 같은 구조 (`emailCheckStatus`, `checkEmail`) — 칸마다 상태 분리
- [x] DioException("중복 확인에 실패했습니다. 다시 시도해 주세요.") vs available: false("이미 사용 중인 닉네임입니다.") 🖼️ `week6-07-signup-error-vs-duplicated.png`

```dart
// lib/view_models/sign_up_view_model.dart (칸 하나의 규칙)
void onChanged(String value) {
  final trimmed = value.trim();
  _currentValue = trimmed;
  _requestVersion++; // 이전 요청의 응답을 무효화한다.

  if (_duplicatedValue != null && trimmed == _duplicatedValue) {
    status = CheckStatus.duplicated;      // API 재호출 없이 즉시 에러 복원
    errorText = duplicatedMessage;
  } else {
    status = CheckStatus.idle;
    errorText = null;
  }
}
```

종료 지점: 닉네임 하나로 확인 전 · 통신 중 · 사용 가능 · 중복 네 상태가 화면에서 구분된다 (🖼️ 01~04).

## 🧪 Guided Practice B — 내가 등록한 평점 화면

1. `RatingDto.fromJson`을 작은 JSON으로 검증 — `comment: null` 포함 (테스트 `RatingDto는 comment가 null이어도 만들어진다`)
2. `RatingApiService.fetchMyRatings(1)` → 실제 응답 3개 (ratingId 3·2·1, movieId 13·680·550)
3. `MyRatingsViewModel` idle → loading

직접 완성할 영역:
- [x] Success / Empty / Error를 `Consumer<MyRatingsViewModel>`로 그리기
- [x] 마이페이지 → 내가 등록한 평점, 앱바 왼쪽 뒤로가기·중앙 제목, 하단 탭 없음
- [x] movieId → TMDB 제목·포스터 (13 포레스트 검프, 680 펄프 픽션, 550 파이트 클럽)
- [x] `writeMyRatingsErrorMessage` 연결 🖼️ `week6-14-ratings-error-404.png`

종료 지점: memberId 1(평점 3개)은 Success, memberId 3(평점 없음)은 Empty로 구분된다.

## 🚀 Required Mission

- [x] 닉네임·이메일 중복 확인 버튼을 `MovieLogButton`으로
- [x] 통신 중 회색 비활성 + 가운데 `CircularProgressIndicator` 🖼️ 02
- [x] width `null` / `double.infinity` / 고정 값 차이를 실제 화면에서 확인 🖼️ 09
- [x] 중복 응답이면 `TextFormField` 에러 상태 + 문구 변경 🖼️ 04
- [x] 수정하면 이전 결과 즉시 무효화 🖼️ 05
- [x] DioException과 `available: false` 문구 구분 🖼️ 07
- [x] 마이페이지에 "내가 등록한 평점" 진입 항목 🖼️ 10
- [x] memberId 1 조회, Loading / Empty / Error / Success 🖼️ 11~14
- [x] movieId를 TMDB 영화 정보와 연결
- [x] `MovieLogButton`은 `lib/widgets/movielog_button.dart` (공용 Widget 위치)

```dart
// lib/widgets/movielog_button.dart
bool get _disabled => isLoading || onPressed == null;

child: isLoading
    ? const SizedBox(width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
    : Text(label),
```

```dart
// lib/router/app_router.dart
static final rootNavigatorKey = GlobalKey<NavigatorState>();
...
GoRoute(
  path: '/my',
  builder: (context, state) => const MyPageScreen(),
  routes: [
    GoRoute(
      path: 'ratings', // /my/ratings
      parentNavigatorKey: rootNavigatorKey, // NavigationBar를 가린다
      builder: (context, state) => ChangeNotifierProvider<MyRatingsViewModel>(
        create: (context) => MyRatingsViewModel(
          context.read<RatingApiService>(),
          context.read<TmdbMovieService>(),
          sampleMemberId, // 학습용 1
        )..load(),
        child: const MyRatingsScreen(),
      ),
    ),
  ],
),
```

## ⭐ Challenge Mission

- [x] 서버가 "중복"이라고 하면 즉시 버튼 비활성 (`canCheck`가 duplicated에서 false) 🖼️ 04 (버튼 회색)
- [x] 다른 문자열로 수정하는 동안 Form 에러 해제 + 버튼 다시 활성 🖼️ 05
- [x] 방금 지운 값과 같은 문자열이면 서버에 묻지 않고 즉시 비활성 + 빨간 에러 🖼️ 06 — 캡처하면서 그 사이 닉네임 요청 수를 셌더니 **0번**

구현: `_duplicatedValue`("마지막으로 중복이었던 값")를 따로 기억하고, `onChanged`에서 trim한 값과 비교한다.

## 🛠 트러블슈팅 기록

(`docs/week6-troubleshooting.md` 5건을 그대로 붙인다 — 템플릿 형식)

1. 통신 중 테스트가 엉뚱한 버튼을 검사 — label이 사라지면 글자로 찾을 수 없다 → 순서로 찾기
2. `double.infinity` 버튼이 화면보다 좁음 — infinity는 "부모가 허용하는" 최대(Form 최대 560)
3. 통신 실패 문구 잘림 — 버튼 옆이라 폭이 좁음 → `errorMaxLines: 2`
4. Loading 캡처가 10초 뒤 Error — Dio receiveTimeout이 동작한 것 (무한 Loading 방지)
5. Empty·404 캡처에 memberId 1 표시 — URL 바꿔치기 대신 `--dart-define=SAMPLE_MEMBER_ID`

## ✅ 최종 체크리스트

- [x] `MovieLogButton`이 기본 · 통신 중 · 비활성 세 상태를 모두 표현한다.
- [x] `MovieLogButton`의 `width`가 `null`, `double.infinity`, 고정 값에서 서로 다르게 동작한다.
- [x] 공용 Button이 화면 전용 폴더가 아닌 공용 Widget 위치에 있다.
- [x] 닉네임·이메일 확인 결과가 Form의 `errorText`와 실제로 연결되어 있다.
- [x] 입력 변경 시 이전 확인 결과가 무효화된다.
- [x] 중복이었던 문자열을 다시 입력하면 재요청 없이 즉시 에러 상태가 된다.
- [x] 통신 실패와 정상 중복 응답을 다른 문구로 구분한다.
- [x] 마이페이지에서 내가 등록한 평점(memberId 1) 화면으로 이동할 수 있다.
- [x] 평점 목록이 Loading / Empty / Error / Success를 모두 표현한다.
- [x] 평점의 `movieId`가 TMDB 영화 정보와 연결되어 표시된다.
- [x] flutter analyze와 Guided/Required 수동 검증 항목을 확인했습니다.

## 📮 제출 양식

```
PR 링크: https://github.com/seoktae-lee/movielog/pull/8
확인 전/통신 중/가능/중복 화면: week6-01 ~ 04
입력 변경 시 무효화 화면 또는 영상: week6-05 (04와 비교)
동일 문자열 재입력 시 즉시 에러 화면 또는 영상: week6-06 (재요청 0번)
MovieLogButton 너비 비교 화면(null / double.infinity / 고정값): week6-09, 실제 화면 week6-08
내가 등록한 평점(memberId 1) Loading/Empty/Error/Success 화면: week6-12 / 13(memberId 3) / 14(memberId 4, 404) / 11
트러블슈팅: 위 5건
6주차 회고: (함께 공부한 뒤 작성)
```

## 💭 6주차 회고

(함께 학습한 뒤 채운다 — 무엇을 알게 됐는지 / 어려웠던 점 / 다음 주에 적용할 점)
