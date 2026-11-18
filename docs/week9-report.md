# 9주차 Frontend 리포트 — 즐겨찾기 연동과 검색, 페이지네이션

## 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| 저장소 | https://github.com/seoktae-lee/movielog |
| 브랜치 | `feature/week-9` (`feature/week-8`에서 분기) |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/11 |
| API | 워크북 서버 `/v8` (8주차 `/v7` 경로만 `/v8`로 교체, 즐겨찾기·영화 기록 신규) |
| 검증 | `flutter analyze` 0 · 테스트 232개 통과 · 실서버 요청 확인(아래 표) |

## 구현한 것

| 영역 | 내용 | 주요 파일 |
| --- | --- | --- |
| 공용 | `SessionGuard`/`AuthSessionBridge`(응답이 현재 로그인 세션 것인지 판정), `SafeNotify`, `mapBounded`(동시 5개) | `lib/core/session/`, `lib/core/utils/` |
| 인증 | 보호 경로 판정을 `/v8`로 교체, 즐겨찾기·영화 기록 추가(method까지 확인) | `lib/core/network/auth_interceptor.dart` |
| 상세 | 북마크 버튼(제목 오른쪽), 진입 시 서버 여부 조회, 서버 성공 뒤에 아이콘 변경, 409/404는 GET으로 서버 상태에 맞춤 | `favorite_detail_view_model.dart`, `favorite_button.dart` |
| 마이페이지 | "내 즐겨찾기" 행 → `/my/favorites`, TMDB 정보 결합(영화 1건 실패는 그 카드만 placeholder + 재조회), 상세에서 돌아오면 재조회 | `favorites_view_model.dart`, `favorites_screen.dart` |
| 영화 목록 | 5주차 "30개 수집"을 `PagedMoviesViewModel`로 대체(한 page씩), 장르 다중 선택 유지, 실패 시 같은 page 재시도, generation으로 늦은 응답 무시 | `paged_movies_view_model.dart`, `movie_page_footer.dart` |
| 검색 | `/movies/search`(정적 경로를 `:movieId`보다 먼저), 제출 시 요청, 빈 검색어는 요청 안 함 | `movie_search_screen.dart` |
| Challenge A | 입력 후 500ms 지나면 자동 검색(debounce), 제출도 유지, dispose에서 타이머 취소 | `movie_search_screen.dart` |
| Challenge B | `ScrollController`로 끝 400px 이내에서 다음 page 자동 요청(기본). `--dart-define=INFINITE_SCROLL=false`면 더 보기 버튼 | `movie_list_screen.dart` |
| Challenge C | 평점 Dialog에 "즐겨찾기에도 추가"(아직 즐겨찾기하지 않은 영화에서만), `POST /v8/movie-records`, 오류 code별로 Dialog 유지/닫기 분기 | `rating_dialog.dart`, `movie_detail_view_model.dart` |

## 실서버(workbook.devnoco.com/v8) 확인 결과

Flutter 웹 debug + 로그인한 Chrome에 붙어 조작했다. 로그인(비밀번호 입력)은 사용자가 직접 했고, 토큰은 캡처·로그에 남기지 않았다.

| 흐름 | 요청 | 결과 |
| --- | --- | --- |
| 상세 진입 | `GET /v8/favorites/1263337` | 200, 버튼 "즐겨찾기 추가" |
| 북마크 등록 | `POST /v8/favorites` | 201, 아이콘 채움 + Snackbar |
| 북마크 해제 | `DELETE /v8/favorites/1263337` | 200(result null), 아이콘 비움 + Snackbar |
| 내 즐겨찾기(없음) | `GET /v8/favorites` | 200, 빈 목록 화면 |
| 내 즐겨찾기(3편) | `GET /v8/favorites` + TMDB 상세 3건 | 최신 등록순, 포스터·평점 결합 |
| 상세에서 해제 → 뒤로 | `DELETE` 200 → `GET /v8/favorites` | 해제한 영화가 목록에서 사라짐 |
| 영화 목록 | TMDB discover page 1 → 2 → 3 | 20편 → 스크롤하면 자동으로 이어 붙음(중복 제거해 78편까지 확인) |
| 검색 | TMDB search | 입력 중 요청 0건, 입력이 멈추고 약 0.6초 뒤 1건(`어벤져스`) |
| 통합 저장 | `POST /v8/movie-records` `{"movieId":27205,"score":4,"comment":"9week-check","addToFavorites":true}` | 201, 북마크가 채워지고 "내 평점 4.0" |
| 409 | `POST /v8/favorites` | 실서버 409 → 앱이 `GET`으로 서버 상태에 맞춤 |
| 404 | `DELETE /v8/favorites/27205` | 실서버 404 → 앱이 `GET`으로 서버 상태에 맞춤 |
| 세션 만료 | `GET /v8/favorites` | 하루가 지난 뒤 실제 401 → 세션을 정리하고 로그인 화면으로 이동 |

## 시뮬레이션으로 만든 것 (정직한 표시)

서버가 일부러 실패해 주지 않는 상황은 브라우저에서 요청을 끊거나 응답 한 번만 바꿔서 만들었다.

- 영화 한 건의 TMDB 상세 실패(그 요청만 끊음) → placeholder + "정보 재조회"
- 내 즐겨찾기 목록 조회 실패(요청 끊음) → 오류 화면 + "다시 시도"
- 다음 page 조회 실패(요청 끊음) → "다음 페이지 다시 시도"
- 검색 오류(요청 끊음) → 오류 화면 + "다시 시도"
- 409/404: **상태 조회 `GET` 응답만 한 번 서버와 반대로 바꿨다.** 그 뒤의 `POST`/`DELETE`는 실서버의 진짜 409/404 응답이다.

## 이번에 확인하지 못한 것

- **로그아웃 후 다른 계정으로 로그인했을 때 이전 계정 즐겨찾기가 안 보이는 화면**: 두 번째 계정의 비밀번호를 내가 입력할 수 없어서 실서버로는 못 찍었다. 대신 `SessionGuard`·`AuthSessionBridge` 단위 테스트와 위젯 테스트(계정 A 로그아웃 → 계정 B 로그인 → 내 즐겨찾기)로 확인했다.
- **더 보기 버튼 방식(Required)**: 기본값이 무한 스크롤(Challenge)이라 실서버로는 무한 스크롤만 찍었다. 버튼 방식은 `INFINITE_SCROLL=false`로 위젯 테스트에서 확인했다.
- **영상**: 이번에는 영상 대신 단계별 캡처와 요청 로그로 대체했다.
- 검증 중 만든 데이터: 영화 3편 즐겨찾기와 평점 1건(`DELETE /v8/ratings/25` 200으로 삭제)을 만들었다. 즐겨찾기 중 오디세이·하트 오브 비스트 2편은 세션이 만료되어 해제하지 못하고 남아 있다.

## 학습 회고

(본인 말로 학습 후 채울 것)
