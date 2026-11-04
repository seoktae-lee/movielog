# 7주차 리포트 — 회원가입과 평점 쓰기 API 연결하기

## 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 브랜치 | `feature/week-7` (feature/week-6에서 분기) |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/9 |
| 사용 API | 워크북 Swagger **v6** — 회원가입 POST, 닉네임/이메일 확인, 평점 조회·등록·수정·삭제 + TMDB 상세 |
| 본인 테스트 계정 | 닉네임 `태이w7ecyy` / 이메일 `taei.w7b.ecyy@movielog.dev` → memberId **8** (비밀번호 기록 안 함) |
| 검증 | `flutter analyze` 0건 / `flutter test` 122개 통과 / 실제 서버 요청 기록 [week7-network-log.md](week7-network-log.md) |

워크북 서버에는 v7(로그인·JWT, `/v7/ratings`)도 이미 열려 있지만, 7주차 Frontend 워크북은 v6 기준이고
"memberId path는 다음 JWT 주차에 토큰으로 바꾼다"고 되어 있어 v6로 진행했다.

## 구현 내용

| 영역 | 파일 |
| --- | --- |
| 공통 응답 | `lib/data/models/common_response.dart` — `CommonResponse<T>`, 실패 body 파싱 `tryParseCommonError` |
| 요청·응답 모델 | `create_member_request.dart` · `sign_up_models.dart`(`SignUpResult`) · `rating_request.dart`(`CreateRatingRequest`·`UpdateRatingRequest`·`validateServerScore`) |
| Service | `sign_up_service.dart`(구 `MemberCheckService` + `signUp`) · `rating_api_service.dart`(+ `createRating`·`updateRating`·`deleteRating`, `writeErrorMessage`, `shouldRefreshAfterRatingError`) |
| 학습용 세션 | `lib/view_models/learning_member_session.dart` — 가입 결과 memberId를 앱 최상단 Provider로 |
| ViewModel | `sign_up_view_model.dart`(`submit`, `SubmitStatus`, `passwordErrorText`/`snackbarMessage`) · `movie_detail_view_model.dart`(`createRating`) · `my_ratings_view_model.dart`(수정·삭제·`refreshWarning`·다중 삭제) |
| 화면 | `sign_up_screen.dart`(가입 POST, PopScope) · `movie_detail_loader.dart`(신규, extra 또는 TMDB 재조회) · `movie_detail_screen.dart`(등록만) · `my_ratings_screen.dart`(카드별 수정·삭제, 편집 모드) |
| 위젯 | `rating_dialog.dart`(정수 별점 + 코멘트 + onSubmit) · `movie_rating_input.dart`(`allowHalfRating: false`) · `my_rating_tile.dart`(수정·삭제 버튼 / CheckBox) · `loading_overlay.dart`(신규) |
| 라우터 | `/movies/:movieId` → `MovieDetailLoader`, `/my/ratings`는 세션 memberId(없으면 가입 안내), 시작 → 회원가입은 `push` |
| 디버그 전용 | `--dart-define=LEARNING_MEMBER_ID=8` (재시작 후에도 학습용 회원으로 시작, release에서는 무시) |

## 설계에서 고른 것

- **응답 계약별 파싱** — 중복 확인·조회 성공은 직접 객체/배열, 회원가입·등록·수정 성공은 Wrapper, 삭제는 204 본문 없음, v6 실패는 모두 Wrapper.
  등록 201의 `result`는 Swagger 설명(ratingId 숫자)과 예시(null)가 달라 읽지 않고, 성공 후 GET으로 확인한다.
- **PATCH는 전체 교체** — `UpdateRatingRequest`는 comment 키를 **항상** 보낸다. Dialog에 기존 코멘트가 채워져 있으니 그대로 두면 유지, 지우면 null(삭제).
- **오류 문구는 서버 message, 다음 행동은 code** — 같은 COMMON404가 등록에서는 "유저", 수정·삭제에서는 "평점"이다. 403·404만 목록을 다시 조회한다.
- **저장 성공 ≠ 재조회 성공** — 쓰기가 성공하면 Dialog는 true로 닫히고, GET만 실패하면 `refreshWarning`과 "조회만 다시 시도"를 보여 준다. POST를 다시 보내 409를 만드는 일을 막는다.
- **최종 409는 해당 칸도 되돌린다** — 중복 확인 뒤 누군가 먼저 가입한 경우 체크 표시를 지우고 duplicated로 바꾼다. (트러블슈팅 1)
- **상세에서는 등록만** — 같은 화면에서 등록에 성공하면 버튼을 "등록 완료 · 수정은 마이페이지에서"로 바꿔 같은 영화에 POST를 반복하지 않는다.

## 실행 화면

모두 실제 v6 서버를 상대로 찍었다. 통신 중 화면은 응답을 잠깐 붙잡고, 네트워크 실패는 요청을 끊어서 재현했다.

| 번호 | 파일 | 내용 |
| --- | --- | --- |
| 01 | `week7-01-signup-ready.png` | 닉네임·이메일 확인 통과, 가입하기 활성 |
| 02 | `week7-02-signup-final-409.png` | 그 사이 다른 사용자가 같은 이메일로 가입 → 최종 409, 이메일 칸 duplicated + Snackbar |
| 03 | `week7-03-signup-invalidated.png` | 이메일을 바꾸자 이전 결과·서버 오류 무효화 |
| 04 | `week7-04-signup-400-password.png` | 서버 400(비밀번호) → 비밀번호 칸 errorText |
| 05 | `week7-05-signup-submitting.png` | 제출 중: 입력·버튼 잠김, 버튼 인디케이터 |
| 06 | `week7-06-signup-success.png` | 201 → /movies, "memberId 8" 안내 |
| 07 | `week7-07-ratings-empty-start.png` | 새 회원의 평점 목록 Empty |
| 08 | `week7-08-detail.png` | 영화 목록 첫 카드 → 상세 (movieId 969681 = TmdbMovieDto.id) |
| 09 | `week7-09-dialog-no-star.png` | 코멘트만 입력, 별점 없음 → 확인 비활성 |
| 10 | `week7-10-dialog-ready.png` | 별 4개(정수) → 확인 활성 |
| 11 | `week7-11-dialog-saving.png` | 저장 중: 버튼 회색 + 인디케이터, 입력 잠김 |
| 12 | `week7-12-register-success.png` | 201 → Dialog 닫힘, 성공 Snackbar |
| 13 | `week7-13-register-409-kept.png` | 같은 영화 재등록 409 → Dialog 유지, 별점·코멘트 보존 |
| 14 | `week7-14-ratings-list.png` | 내가 등록한 평점 6개, 카드별 수정·삭제 |
| 15 | `week7-15-edit-prefilled.png` | 수정 Dialog: 기존 5점·코멘트가 채워짐 |
| 16 | `week7-16-edit-success.png` | PATCH 200 → 목록 재조회 (4점, 코멘트 변경) |
| 17 | `week7-17-refresh-fail.png` | PATCH 200 뒤 GET만 실패 → "저장은 완료됐지만…" |
| 18 | `week7-18-refresh-retry-ok.png` | 조회만 다시 시도 → 목록 |
| 19 | `week7-19-edit-null-comment.png` | comment null 평점 → 빈 칸으로 시작 |
| 20 | `week7-20-edit-403.png` | 403 "본인이 작성한 평점만…" (Dialog 안) |
| 21 | `week7-21-edit-404.png` | 다른 기기에서 먼저 삭제 → 404 "존재하지 않는 평점입니다." + 뒤 목록 재조회 |
| 22 | `week7-22-delete-confirm.png` | 삭제 확인 Dialog (취소하면 요청 없음) |
| 23 | `week7-23-delete-loading.png` | 단건 삭제 중: Dialog 유지 + 버튼 인디케이터 |
| 24 | `week7-24-delete-success.png` | 204 → 목록 갱신 (5개 → 4개) |
| 25 | `week7-25-list-after-register.png` | 상세에서 등록한 "대부"가 마이페이지 목록에 재조회됨 |
| 26 | `week7-26-multi-selected.png` | 편집 모드: CheckBox, "3개 선택", 취소, 하단 "선택한 3개 삭제" |
| 27 | `week7-27-multi-confirm.png` | 다중 삭제 확인 Dialog |
| 28 | `week7-28-multi-overlay.png` | Dialog는 닫히고 화면 위 ModalBarrier + 흰 인디케이터 |
| 29 | `week7-29-multi-partial.png` | 1건 실패 → 성공한 2건만 사라지고 실패 1건은 선택 유지 + Snackbar |
| 30 | `week7-30-multi-empty.png` | 남은 평점 전부 삭제 → Empty |

영상(GIF, 360px):

| 파일 | 내용 |
| --- | --- |
| `week7-gif-register-refresh.gif` | 상세에서 평점 등록 → 성공 Snackbar → 마이페이지 "내가 등록한 평점"에서 재조회 |
| `week7-gif-edit.gif` | 수정 → 목록 재조회 |
| `week7-gif-refresh-retry.gif` | 저장 성공 후 GET만 실패 → GET 재시도 |
| `week7-gif-delete.gif` | 삭제 확인 → 삭제 중 → 목록 갱신 |
| `week7-gif-multi-delete.gif` | 편집 → 3개 선택 → 오버레이 → 일부 실패 → 나머지 삭제 → Empty |

## 트러블슈팅

[week7-troubleshooting.md](week7-troubleshooting.md) — 6건

## 학습 회고

- 알게 된 점: 저장 성공과 목록 재조회 성공은 다른 상태라 따로 다뤄야 한다. PATCH도 API 계약에 따라 전체 교체일 수 있다.
- 어려웠던 점: API마다 성공 응답 형태(직접 배열, Wrapper, 204)가 달라 각각 맞춰 처리해야 했다.
- 다음 주에 적용할 점: memberId는 인증이 아니므로 JWT 토큰으로 회원을 식별하도록 바꾼다.
