# 6주차 리포트 — 중복 확인 연동과 평점 조회하기

## 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 브랜치 | `feature/week-6` (feature/week-5에서 분기) |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/8 |
| 사용 API | 워크북 Swagger v5 — 닉네임/이메일 중복 체크, 유저별 평점 조회 + TMDB `GET /movie/{id}` |
| 검증 | `flutter analyze` 0건 / `flutter test` 81개 통과 |

## 구현 내용

| 영역 | 파일 |
| --- | --- |
| 공용 버튼 | `lib/widgets/movielog_button.dart` |
| 워크북 Client | `lib/core/network/movie_log_client.dart` (baseUrl `https://workbook.devnoco.com`, TMDB Client와 분리) |
| 모델 | `lib/data/models/check_result.dart` · `rating_dto.dart` · `rating_with_movie.dart` |
| Service | `lib/data/services/member_check_service.dart` · `rating_api_service.dart` · `tmdb_movie_service.dart`(`findMovieById` 추가) |
| ViewModel | `lib/view_models/sign_up_view_model.dart` · `my_ratings_view_model.dart` |
| 화면 | `lib/screens/sign_up_screen.dart`(Row + 버튼) · `my_page_screen.dart`(진입 행) · `my_ratings_screen.dart`(신규) |
| 라우터 | `lib/router/app_router.dart` — `rootNavigatorKey`, `/my/ratings`에 `parentNavigatorKey` |
| 디버그 전용 | `/debug/buttons` 너비 비교 화면, `--dart-define=INITIAL_LOCATION=...`, `--dart-define=SAMPLE_MEMBER_ID=3` |

5주차 Backend 미션 때 만든 임시 구조(`MovieLogMemberService`, 로컬 Spring 서버 `localhost:8080`)는
6주차 워크북 구조(Service 둘로 분리, 워크북 서버 v5)로 바꾸면서 지웠다.

## 실제 API로 확인한 값

| 요청 | 결과 |
| --- | --- |
| `GET /v5/members/nickname/영화광` | `{"available":false}` (중복 예시) |
| `GET /v5/members/email/movie@umc.com` | `{"available":false}` |
| `GET /v5/members/1/ratings` | 3개 (movieId 13·680·550, ratingId 3의 comment는 null) |
| `GET /v5/members/3/ratings` | `[]` → Empty |
| `GET /v5/members/4/ratings` | 404 `존재하지 않는 유저입니다.` → Error |
| `GET /v5/members/abc/ratings` | 400 `Validation failed (numeric string is expected)` |

## 실행 화면

| 번호 | 파일 | 내용 |
| --- | --- | --- |
| 01 | `week6-01-signup-idle.png` | 확인 전 |
| 02 | `week6-02-signup-checking.png` | 통신 중 (회색 + 인디케이터) |
| 03 | `week6-03-signup-available.png` | 사용 가능 (입력창 안 체크) |
| 04 | `week6-04-signup-duplicated.png` | 중복 (에러 + 버튼 비활성) |
| 05 | `week6-05-signup-invalidated.png` | 한 글자 지움 → 무효화 |
| 06 | `week6-06-signup-same-again.png` | 같은 값 재입력 → 즉시 에러 (요청 0번) |
| 07 | `week6-07-signup-error-vs-duplicated.png` | 통신 실패 vs 중복 문구 |
| 08 | `week6-08-signup-ready.png` | 모두 확인 → 가입하기(전체 너비) 활성 |
| 09 | `week6-09-button-width.png` | width null / 96 / infinity, 상태 3개 |
| 10 | `week6-10-mypage-entry.png` | 마이페이지 진입 행 |
| 11 | `week6-11-ratings-success.png` | Success (NavigationBar 없음) |
| 12 | `week6-12-ratings-loading.png` | Loading |
| 13 | `week6-13-ratings-empty.png` | Empty (memberId 3) |
| 14 | `week6-14-ratings-error-404.png` | Error 404 (memberId 4) |
| 15 | `week6-15-ratings-error-network.png` | Error 네트워크 실패 |

캡처는 Flutter 웹(디버그) + 헤드리스 Chrome으로 실제 서버에 요청해서 찍었다.
통신 중·Loading은 응답을 잠깐 붙잡아 두고, 통신 실패는 요청을 끊어서 재현했다.

## 트러블슈팅

[week6-troubleshooting.md](week6-troubleshooting.md) — 5건

## 학습 회고

(함께 학습한 뒤 작성)
