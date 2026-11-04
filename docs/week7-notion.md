# 7주차 Frontend 노션 제출본 (원고)

> 노션 7주차 Frontend 페이지에 위에서부터 붙여넣는 원고. 워크북 순서 그대로다.
> `🖼️` 표시 자리에 이미지/GIF를 드래그한다. **토글 안에 넣지 말 것** (채점에서 빠질 수 있음).

## 📌 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/9 |
| 브랜치 | `feature/week-7` |
| 사용 API | 워크북 Swagger v6 (`https://workbook.devnoco.com/v6`) + TMDB 상세 |
| 본인 테스트 계정 | 닉네임 `태이w7ecyy` / 이메일 `taei.w7b.ecyy@movielog.dev` → memberId 8 (비밀번호 미기록) |
| 검증 | `flutter analyze` 0건 / `flutter test` 122개 통과 / 실제 서버로 회원가입·등록·조회·수정·삭제 확인 |

## 📸 스터디 인증

- [x] 회원가입 성공과 최종 중복 409 화면
  🖼️ `week7-02-signup-final-409.png` — 중복 확인을 통과한 뒤 다른 사용자가 같은 이메일로 먼저 가입 → POST 409 "이미 사용 중인 이메일입니다." Snackbar + 이메일 칸이 다시 중복 에러, 가입하기 비활성
  🖼️ `week7-06-signup-success.png` — 201, result.memberId 8을 학습용 세션에 저장하고 /movies로 이동
- [x] 평점 등록 → 목록 재조회 영상
  🖼️ `week7-gif-register-refresh.gif` — 상세에서 별 5개 + 코멘트 → 201 → 성공 Snackbar → 마이페이지 "내가 등록한 평점"에서 GET으로 다시 읽어 "대부"가 맨 위에 보임
- [x] 평점 수정 → 목록 재조회 영상
  🖼️ `week7-gif-edit.gif` — 인터스텔라 5점 → 4점, 코멘트 변경 → PATCH 200 → GET 재조회
- [x] 삭제 취소 / 삭제 성공 / 빈 목록 화면
  🖼️ `week7-22-delete-confirm.png` (취소하면 DELETE 요청 0건) · `week7-24-delete-success.png` (204 → 5개 → 4개) · `week7-30-multi-empty.png` (마지막 평점까지 삭제 → Empty)
- [x] 저장 실패 후 입력이 유지되는 화면
  🖼️ `week7-13-register-409-kept.png` — 같은 영화 재등록 409 "이미 이 영화에 평점을 남기셨습니다." Dialog가 닫히지 않고 별 5개·"두 번째 감상평" 그대로, 확인 버튼 다시 활성
- [x] 저장 성공 후 GET만 실패했을 때 GET 재시도 영상
  🖼️ `week7-gif-refresh-retry.gif` + `week7-17-refresh-fail.png` → `week7-18-refresh-retry-ok.png` — PATCH 200 뒤 GET만 차단 → "저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요." → 다시 시도는 GET만 보냄(PATCH 재전송 없음)
- [x] 영화 상세에서 평점 등록 후 성공 Snackbar가 표시되고, 마이페이지의 학습용 회원 평점 목록에서 재조회되는 영상
  🖼️ `week7-12-register-success.png` + `week7-25-list-after-register.png` (영상은 위 `week7-gif-register-refresh.gif`)
- [x] 평점 등록 Dialog에 별점 아래 코멘트 TextField가 추가되고, 별점을 선택해야 확인 버튼이 활성화되는 화면
  🖼️ `week7-09-dialog-no-star.png` (코멘트만 입력 → 확인 회색) → `week7-10-dialog-ready.png` (별 4개 → 확인 보라색) · `week7-11-dialog-saving.png` (저장 중 회색 + 인디케이터)
- [x] 내가 등록한 평점 화면에서 수정 버튼을 누르면 기존 별점·코멘트가 채워진 Dialog가 뜨는 화면
  🖼️ `week7-15-edit-prefilled.png` (5점 + "음악이 압도적") · `week7-19-edit-null-comment.png` (comment null → 빈 칸)
- [x] 삭제 확인 Dialog와 삭제 후 목록이 갱신되는 화면
  🖼️ `week7-22-delete-confirm.png` → `week7-23-delete-loading.png` → `week7-24-delete-success.png` (영상 `week7-gif-delete.gif`)
- [x] flutter analyze 결과와 Guided/Required 수동 검증 결과, PR

```
$ flutter analyze
No issues found!

$ flutter test
+122: All tests passed!
```

실제 서버 요청 기록(발췌, 전체는 저장소 docs/week7-network-log.md):

```
POST /v6/members → 409   (다른 사용자가 같은 이메일로 먼저 가입)
POST /v6/members → 400   (앱 검사가 먼저 막으므로, 요청 body의 비밀번호만 약한 값으로 바꿔 재현)
POST /v6/members → 201   memberId 8
POST /v6/members/8/ratings → 201  {movieId: 969681, score: 4, comment}
POST /v6/members/8/ratings → 409  (같은 영화 재등록)
PATCH /v6/members/8/ratings/11 → 200 → GET /v6/members/8/ratings → 200
PATCH /v6/members/8/ratings/9 → 200 → GET (캡처 도구로 차단) → GET 재시도 200
PATCH /v6/members/8/ratings/1 → 403  → GET 재조회  (화면엔 내 평점만 있어, 요청 경로의 ratingId만 1로 바꿔 재현)
PATCH /v6/members/8/ratings/7 → 404  → GET 재조회  (스크립트로 같은 평점을 먼저 삭제해 재현)
DELETE /v6/members/8/ratings/6 → 204 → GET → 200
```

## 🎯 핵심 개념

1. **HTTP Method의 역할** — GET 조회(body 없음) / POST 생성(201) / PATCH 수정(200) / DELETE 삭제(204, body 없음). 요청 body가 있는 건 POST·PATCH뿐이다.
2. **toJson과 fromJson은 방향이 반대** — `CreateMemberRequest.toJson()`은 Dart 객체 → 요청 JSON, `SignUpResult.fromJson()`은 응답 JSON → Dart 객체. 요청 Model과 응답 Model을 따로 둔다.
3. **CommonResponse<T>** — `isSuccess / code / message / result`. result는 API마다 달라서 제네릭 T와 `parseResult` 함수로 받는다. result가 null이면 parseResult를 부르지 않는다.
4. **API별 성공 계약이 다르다** — 중복 확인·조회 성공은 v5 그대로 직접 객체/배열, 회원가입·등록·수정 성공은 Wrapper, 삭제는 204라 본문 없음. v6 실패는 전부 Wrapper. 그래서 Service가 API마다 다르게 파싱한다. 204를 `response.data as Map`으로 읽지 않는다.
5. **등록 result는 강제 캐스팅하지 않는다** — Swagger 설명은 "ratingId 숫자", 예시는 null. 계약이 확정되기 전에는 201만 성공으로 보고 GET으로 목록을 다시 확인한다.
6. **PATCH인데 전체 교체** — v6 수정은 score 필수, comment를 빼면 기존 후기가 null로 덮인다. 그래서 `UpdateRatingRequest`는 comment 키를 항상 보낸다. 수정 Dialog에 기존 코멘트를 채워 두니 그대로 두면 유지, 지우면 삭제 의도가 분명해진다.
7. **정수 score** — v6 score는 1~5 정수. `allowHalfRating: false`로 별 한 개 단위로만 고르게 하고, `validateServerScore`로 한 번 더 확인한다. 반 점을 조용히 `toInt()`로 깎지 않는다.
8. **memberId는 인증이 아니다** — 가입 결과 memberId를 `LearningMemberSession`(앱 최상단 ChangeNotifierProvider)에 보관해 상세·마이페이지가 같은 값을 쓴다. 6주차 상수 1을 계속 쓰면 남의 path로 요청하게 된다. memberId만 알면 누구나 요청할 수 있으므로 다음 주 JWT에서 토큰으로 바꾼다.
9. **오류 문구는 message, 다음 행동은 code** — 같은 COMMON404가 등록에선 "존재하지 않는 유저", 수정·삭제에선 "존재하지 않는 평점". 문구는 서버 message를 그대로 보여 주고, code는 "다시 조회할지"만 정한다(403·404 → 재조회, 400·409 → 그 자리에서 고치기).
10. **400의 목적지 나누기** — 비밀번호 형식 400은 비밀번호 칸 `errorText`(필드 단위), 그 밖의 400·409는 Snackbar(화면 단위).
11. **최종 409** — 중복 확인 GET은 그 순간의 결과일 뿐. 가입 POST의 409가 최종 판단이고, 받으면 해당 칸 체크 표시도 되돌린다.
12. **저장 성공 ≠ 재조회 성공** — 쓰기 성공 뒤 GET만 실패하면 Dialog는 성공(true)으로 닫고, 목록 자리에 "조회만 다시 시도"를 보여 준다. 저장 실패로 처리하면 사용자가 다시 저장해 409를 만난다.
13. **Dialog 안에서 저장 + 이탈 막기** — `onSubmit` 콜백을 Dialog 안에서 실행하고 `_isSubmitting`을 `MovieLogButton.isLoading`과 `PopScope(canPop: !_isSubmitting)`에 연결. 바깥 탭은 `showDialog(barrierDismissible: false)`로 막는다. 둘 중 하나만 걸면 뚫린다.
14. **실패하면 로딩을 반드시 푼다** — catch에서 `_isSubmitting = false`로 되돌려야 다시 시도할 수 있다. 입력값(별점·코멘트)은 건드리지 않는다.
15. **TextEditingController는 State에서 한 번** — `late final _commentController`로 만들고 dispose. build 안에서 만들면 별점 setState마다 코멘트가 지워진다.
16. **await 뒤 mounted 확인** — 저장 요청과 Snackbar 표시는 다른 비동기 경계. 화면을 떠난 뒤 온 응답은 반영하지 않는다(ViewModel `_disposed`, 화면 `mounted`).
17. **다중 삭제는 Dialog를 먼저 닫는다** — 확인 Dialog는 "삭제할까?"만 묻고 pop, 요청은 화면 ViewModel이 이어받아 `isDeletingSelected`로 Stack 오버레이를 띄운다. 원본 Set을 돌면서 remove하면 ConcurrentModificationError → `toList()`로 복사해 순회, 실패한 id는 선택에 남긴다.

## 🧪 Guided Practice A — 회원가입

1. v6 Swagger `POST /v6/members` — 요청 `CreateMemberDto {email, password, nickname}`, 201 result `{memberId, email, nickname}`, 실패 400(비밀번호)·409(이메일 먼저 검사 후 닉네임)
2. `CommonResponse<T>`와 `SignUpResult` 작성
3. `MemberCheckService` → `SignUpService`로 이름 변경, 경로 v5 → v6, `signUp` 추가
4. `SignUpViewModel`에 `SubmitStatus { idle, submitting, success, error }`

직접 완성할 영역:
- [x] 비밀번호 400은 `passwordErrorText`, 다른 400·409는 `snackbarMessage` 🖼️ 04 / 02
- [x] 성공하면 /movies, 실패하면 Snackbar 🖼️ 06 / 02
- [x] 닉네임·이메일을 바꾸면 이전 중복 확인 결과와 서버 오류 함께 무효화 🖼️ 03
- [x] 로컬 validator(서버와 같은 정규식) + 서버 400 `errorText` 동시 연결

```dart
// lib/view_models/sign_up_view_model.dart
Future<void> submit(CreateMemberRequest request) async {
  if (isSubmitting) return; // 연속 탭 방지
  submitStatus = SubmitStatus.submitting;
  createdMemberId = null;
  passwordErrorText = null;
  snackbarMessage = null;
  _notify();

  try {
    final response = await _service.signUp(request);
    final id = response.result?.memberId;
    if (id == null) throw StateError('회원가입 결과에 memberId가 없습니다.');
    createdMemberId = id;
    submitStatus = SubmitStatus.success;
  } on DioException catch (error) {
    submitStatus = SubmitStatus.error;
    final message = writeSignUpErrorMessage(error); // 서버 message 그대로
    final status = error.response?.statusCode;
    if (status == 400 && message.contains('비밀번호')) {
      passwordErrorText = message;   // 필드 단위
    } else {
      snackbarMessage = message;     // 화면 단위
    }
    if (status == 409) {             // 최종 중복: 체크 표시를 되돌린다
      if (message.contains('이메일')) _email.markDuplicated(request.email);
      if (message.contains('닉네임')) _nickname.markDuplicated(request.nickname);
    }
  } on StateError {
    submitStatus = SubmitStatus.error;
    snackbarMessage = '가입 결과를 확인하지 못했습니다. 새 요청 전에 서버 상태를 확인해 주세요.';
  }
  _notify();
}
```

종료 지점: 실제 서버에서 409 → 400 → 201(memberId 8) 순서로 확인 (🖼️ 01~06).

## 🧪 Guided Practice B — 영화 상세에서 평점 등록하기

1. 목록에서 고른 `TmdbMovieDto`를 GoRouter `extra`로 넘김. URL로 바로 들어오면 `MovieDetailLoader`가 TMDB `GET /movie/{id}`로 다시 조회
2. `RatingDialog`에서 정수 별점 + 코멘트(최대 500자, 빈 문자열 → null)
3. `MovieDetailViewModel.createRating` → `POST /v6/members/{memberId}/ratings` `{movieId: TmdbMovieDto.id, score, comment}`

직접 완성할 영역:
- [x] 성공이면 "평점을 등록했습니다…" Snackbar, 실패(400/404/409)면 Dialog 안에 서버 message 🖼️ 12 / 13
- [x] 저장 중 확인 버튼 재탭 불가 (회색 + 인디케이터) 🖼️ 11

```dart
// lib/screens/movie_detail_screen.dart
final saved = await showDialog<bool>(
  context: context,
  barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
  builder: (_) => RatingDialog(
    onSubmit: (score, comment) async {
      await viewModel.createRating(score: score, comment: comment);
      if (viewModel.submitStatus != SubmitStatus.success) {
        throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
      }
    },
  ),
);
if (!mounted || saved != true) return;
_showSnackBar('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
```

종료 지점: 상세 movieId 969681(목록 첫 카드)로 201, 같은 영화 재등록은 409로 Dialog 유지.

## 🚀 Required Mission

회원가입
- [x] 닉네임·이메일 중복 확인이 모두 통과해야 가입하기 활성 🖼️ 01
- [x] 성공 시 result.memberId 확인 — Snackbar "(memberId 8)" 🖼️ 06
- [x] 비밀번호 400 → 비밀번호 칸 errorText, 그 외 400·409 → Snackbar 🖼️ 04 / 02
- [x] 제출 중 중복 탭 막기 🖼️ 05

내가 등록한 평점 (LearningMemberSession.memberId로 조회, 왼쪽 뒤로가기·중앙 제목, NavigationBar 없음)
- [x] 카드 오른쪽 수정 → 기존 score/comment가 채워진 RatingDialog, comment null이면 빈 칸 🖼️ 15 / 19
- [x] score는 항상, comment는 Dialog 값 그대로 보내 유지/삭제 의도 명확 (`{score, comment}` 전체 교체)
- [x] 수정 성공 후 재조회 🖼️ 16
- [x] 등록·수정 중 Dialog 닫기·화면 이탈 불가 (PopScope + barrierDismissible: false)
- [x] 카드 오른쪽 삭제 → 확인 Dialog, 취소하면 요청 없음 🖼️ 22
- [x] DELETE 204 body 파싱 안 함, 성공 후 재조회, 마지막 항목 삭제 시 Empty 🖼️ 24 / 30

예외 흐름
- [x] 400/403/404/409 구별 — 403 "본인이 작성한 평점만 수정하거나 삭제할 수 있습니다." 🖼️ 20 / 404 "존재하지 않는 평점입니다." 🖼️ 21 / 409 🖼️ 13 / 400 🖼️ 04
- [x] 연속 탭 방지 + 실패 시 입력 보존 🖼️ 13
- [x] 화면 이탈 뒤 이전 요청 결과 미반영 (ViewModel `_disposed`, 화면 `mounted`)

```dart
// lib/view_models/my_ratings_view_model.dart
Future<void> updateRating({required int ratingId, required int score, String? comment}) async {
  try {
    await _service.updateRating(
      memberId: memberId, ratingId: ratingId, score: score, comment: comment,
    );
  } on DioException catch (error) {
    if (shouldRefreshAfterRatingError(error)) await load(); // 403·404만 재조회
    rethrow; // 쓰기 실패만 Dialog가 실패로 처리
  }
  await _refreshAfterWrite(); // GET 실패는 저장 실패로 다시 던지지 않는다
}

Future<void> _refreshAfterWrite() async {
  await load();
  if (status == MyRatingsLoadStatus.error) {
    refreshWarning = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';
    notifyListeners();
  }
}
```

## ⭐ Challenge Mission

회원가입
- [x] 제출 중 화면 이탈 불가 — `PopScope(canPop: !isSubmitting)`, AppBar 뒤로가기도 `Navigator.maybePop`이라 같이 막힘. 시작 화면에서 `push`로 열어 제출이 끝나면 다시 뒤로 갈 수 있다 🖼️ 05

내가 등록한 평점
- [x] 상단 오른쪽 "편집" → 다중 선택 모드, 같은 줄 왼쪽 "N개 선택", 오른쪽 "취소" 🖼️ 26
- [x] 카드별 수정·삭제 버튼 대신 CheckBox, 취소하면 선택 해제
- [x] 선택이 1개 이상일 때만 하단 "선택한 N개 삭제" 활성
- [x] 확인 Dialog는 요청 전에 바로 pop, 이후 화면 위 ModalBarrier + 흰 인디케이터 + PopScope 🖼️ 27 / 28 (단건 삭제는 Dialog 유지 🖼️ 23)
- [x] 일부 실패 시 성공한 항목만 사라지고 실패 항목은 선택 유지 + "1개 항목을 삭제하지 못했습니다…" 🖼️ 29 (영상 `week7-gif-multi-delete.gif`)

## 🛠 트러블슈팅 기록

(`docs/week7-troubleshooting.md` 6건을 그대로 붙인다 — 템플릿 형식)

1. 중복 확인 통과 후 최종 가입 409인데 이메일 칸에 체크 표시가 남음 → 409 message로 해당 칸을 duplicated로 되돌림
2. 서버 비밀번호 400을 화면에서 재현할 수 없음 → 클라이언트 validator가 같은 규칙(의도한 동작), body만 바꿔 실제 서버로 재현
3. 회원가입 Widget 테스트 "No GoRouter found in context" → `context.canPop()` 대신 `Navigator.canPop/maybePop`
4. 저장 중 PopScope 테스트가 true → 별 탭 뒤 pump 누락으로 확인 버튼이 아직 비활성
5. 다중 삭제 테스트 pumpAndSettle이 끝나지 않음 → 계속 도는 인디케이터, `pump(Duration)`으로 진행
6. 캡처 중 이메일이 이어 붙어 형식 오류 → 스크립트의 입력 지우기 방식 수정 (앱 validator는 정상)

## ✅ 최종 체크리스트

- [x] 닉네임·이메일 확인 상태가 입력 변경 후 무효화됩니다.
- [x] 확인 true/false와 통신 실패, 최종 가입 409를 구분합니다.
- [x] 요청 Model과 응답 Model을 구분했습니다.
- [x] 정수 score 1~5만 전송합니다.
- [x] movieId는 5주차 `TmdbMovieDto.id`이며 영화 배열 index나 임의 번호가 아닙니다.
- [x] movieId와 ratingId를 구분합니다.
- [x] TMDB 제목·포스터와 MovieLog 평점 응답을 movieId로 연결합니다.
- [x] 직접 배열/wrapper/204를 각각 처리합니다.
- [x] 저장 실패와 재조회 실패를 구분합니다.
- [x] 비밀번호와 타인 데이터를 기록하지 않았습니다.
- [x] 등록·수정·삭제 뒤 서버 목록을 확인했습니다.
- [x] flutter analyze와 Guided/Required 수동 검증 항목을 확인했습니다.

## 📮 제출 양식

```
PR 링크: https://github.com/seoktae-lee/movielog/pull/9
생성한 본인 테스트 계정(비밀번호 제외): 닉네임 태이w7ecyy / 이메일 taei.w7b.ecyy@movielog.dev → memberId 8
닉네임/이메일 확인과 입력 변경 무효화: week7-01(둘 다 통과) → week7-03(이메일 변경 → 이전 결과·409 오류 무효화)
회원가입 결과와 최종 409: week7-02(POST 409 "이미 사용 중인 이메일입니다.") → week7-06(201, memberId 8)
선택한 TMDB id → MovieLog movieId 증거: 영화 목록 첫 카드 → 상세 "movieId 969681"(week7-08) → POST body {movieId: 969681, score: 4, comment: "극장에서 다시 보고 싶다"} → 201
등록→조회→수정→조회→삭제→조회 증거: POST 201 → GET 200(week7-14) → PATCH 200 → GET 200(week7-16) → DELETE 204 → GET 200(week7-24), 영상 week7-gif-register-refresh / edit / delete
오류 code 처리 증거: 400 비밀번호(week7-04), 403(week7-20), 404(week7-21, 이후 재조회), 409 등록(week7-13)·가입(week7-02)
저장 성공/재조회 실패 분리 증거: PATCH 200 → GET 네트워크 차단 → "저장은 완료됐지만…"(week7-17) → 조회만 재시도 GET 200(week7-18), 영상 week7-gif-refresh-retry
트러블슈팅: 위 6건
미검증 항목: 캡처·영상은 Flutter 웹(디버그) + 헤드리스 Chrome으로 실제 v6 서버를 상대로 만들었고, iOS 시뮬레이터·실기기에서는 실행하지 않음. 스와이프 백 제스처는 Widget 테스트(PopScope.canPop=false)로만 확인. 403은 화면에 남의 평점이 없어 요청 경로의 ratingId를 바꿔 재현.
```

## 💭 7주차 회고

- 알게 된 점: 저장 성공과 목록 재조회 성공은 다른 상태라 따로 다뤄야 한다. PATCH도 API 계약에 따라 전체 교체일 수 있다.
- 어려웠던 점: API마다 성공 응답 형태(직접 배열, Wrapper, 204)가 달라 각각 맞춰 처리해야 했다.
- 다음 주에 적용할 점: memberId는 인증이 아니므로 JWT 토큰으로 회원을 식별하도록 바꾼다.
