# 5주차 미션 완료 정보 (Frontend) — TMDB 영화 API와 MVVM·Provider

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| 브랜치 | `feature/week-5` (PR #6 `feature/week-4`에서 분기) |
| Pull Request | (PR 생성 후 기입) |
| 추가한 Package | `dio 5.11.1`, `provider 6.1.5+1`, `flutter_dotenv 6.0.1` (제거: `shared_preferences`) |
| `flutter analyze` | `No issues found!` |
| `flutter test` | 50개 통과 |
| 트러블슈팅 | `docs/week5-troubleshooting.md` (7건) |
| 환경 | Flutter 3.47.3 / Dart 3.13.3, iPhone 17 시뮬레이터 |
| 캡처 | `week5-01-home-popular` · `02-movies-30` · `03-genre-action` · `04-loading` · `05-empty` · `06-error-401` · `07-placeholder` · `08-retry-dialog` |

## 구조 — UI Layer와 Data Layer

```
lib/
├─ main.dart                      dotenv.load → runApp
├─ app/movie_log_app.dart         MultiProvider(TmdbMovieService) → MaterialApp.router
├─ router/app_router.dart         Route마다 ChangeNotifierProvider(ViewModel..load())
├─ core/
│  ├─ config/tmdb_config.dart     .env의 TMDB_ACCESS_TOKEN 읽기 + 비었는지 검사
│  └─ network/
│     ├─ tmdb_client.dart         TMDB 전용 Dio (baseUrl·timeout·Bearer)
│     └─ tmdb_logging_interceptor.dart  요청·응답·오류 로그, Authorization → Bearer ***
├─ data/                          ── Data Layer ──
│  ├─ models/ tmdb_movie_dto · tmdb_movie_page · tmdb_genre_dto · create_rating_request
│  └─ services/tmdb_movie_service.dart  HTTP + DTO 변환만 (stateless)
├─ view_models/                   ── UI Layer (상태) ──
│  ├─ movie_home_view_model.dart  Popular take(5)
│  ├─ movie_list_view_model.dart  Genre + Discover 최대 30개, 장르 재조회, 새로고침
│  └─ movie_detail_view_model.dart  DTO 재사용 / URL 진입 시 movieId로 상세 조회
├─ screens/                       ── UI Layer (View) ──
└─ widgets/ tmdb_poster_image · tmdb_movie_card · movie_card · movie_grid · genre_chips …
```

## 데이터 흐름 (장르 선택)

```
[View] 장르 Chip 탭
  │ context.read<MovieListViewModel>().selectGenre(28)
  ▼
[ViewModel] isBusy면 무시 → selectedGenreIds=[28], movies 비움, status=loading → notifyListeners()
  │ fetchUpToThirtyMovies(genreIds: [28])   ← page 1부터, TMDB id 기준 중복 제거, 30개 or 마지막 페이지에서 멈춤
  ▼
[Service] GET /discover/movie?page=1&with_genres=28&sort_by=popularity.desc…  → TmdbMoviePageDto
  ▼
[ViewModel] version이 최신일 때만 반영 → success / empty / error → notifyListeners()
  ▼
[View] Consumer의 builder만 다시 실행 → MovieGrid / Empty / Error / Loading
```

## 요구사항 대응

| 요구사항 | 구현 위치 |
| --- | --- |
| Token을 코드에 쓰지 않음 | `.env`(gitignore) + `TmdbConfig` / `.env.example`만 커밋 |
| 로그에 Token 비노출 | `TmdbLoggingInterceptor.maskHeaders` (복사본만 마스킹) / release에선 미등록 |
| 인기 5개 | `MovieHomeViewModel.loadPopular` — `take(5)` |
| 최대 30개 | `MovieListViewModel.fetchUpToThirtyMovies` — `Map<int, dto>` + `total_pages` 종료 |
| 장르 → `with_genres` 재요청 | `selectGenre`/`selectGenres` → `_reloadMovies` (page 1부터) |
| "전체"는 `with_genres` 없음 | `TmdbMovieService.discoverMovies` — 빈 목록이면 Key 자체를 안 넣음 |
| 요청 중 장르 변경 금지 | `isBusy` → `GenreChips(enabled:)`, 필터 버튼 비활성 + ViewModel에서도 무시 |
| 늦은 응답 무시 | `_requestVersion` |
| 4상태 | Loading(Skeleton) / Empty / Error(다시 시도) / Success(`인기순 N편` + Grid) |
| 포스터 null·실패 | `TmdbPosterImage` — null·빈 문자열 → placeholder, `errorBuilder` → placeholder |
| 줄거리·개봉일 null | "줄거리 정보가 없어요." / 연도 표시 생략 |
| `movie.id` 전달 | `context.push('/movies/${movie.id}', extra: movie)` → `RatingDialog(movieId:)` → `CreateRatingRequest(movieId, score)` |
| Challenge: Pull to Refresh | `RefreshIndicator` + `refresh()` (기존 목록 유지, Loading 중 비활성) |
| Challenge: 장르 다중 선택 | `GenreFilterSheet` 재사용, `List<int>` → `28|18` |
| Challenge: 재시도 Dialog | 새로고침 실패 시 목록 유지 + 취소/재시도 |
| Challenge: 오류 로그 재현 | Token 없이 401 (트러블슈팅 1) / Wi-Fi 끄고 connectionError (트러블슈팅 7) |

## 4주차에서 바뀐 점

- 4주차의 `FutureBuilder` + `MovieService`/`FakeMovieService` → ViewModel의 `status`로 대체.
- 장르를 URL Query(이름)로 들고 있던 방식 → ViewModel의 `selectedGenreIds`(TMDB id)로 이동. 장르 이름을 하드코딩하지 않고 Genre API 값을 쓴다.
- `SharedPreferences` 장르·정렬 저장은 TMDB 정렬(`popularity.desc` 고정)·장르 id 체계와 맞지 않아 이번 주에 제거했다.
- 마이페이지 즐겨찾기는 아직 Mock이라 상세로 이동하지 않는다(상세는 TMDB id 기준).

## 테스트 (50개)

| 파일 | 내용 |
| --- | --- |
| `tmdb_dto_test.dart` | snake_case·null·num 변환, 상세 응답 `genres`, 페이지 metadata |
| `tmdb_movie_service_test.dart` | 경로·Query·Bearer Header, 전체일 때 `with_genres` 없음, `28|12`, 로그에 Token 없음 |
| `movie_home_view_model_test.dart` | take(5), 5개 미만, Empty/Error, Loading → Success 순서 |
| `movie_list_view_model_test.dart` | 30개·중복 제거·마지막 페이지·빈 페이지, 장르 재조회, 요청 중 잠금, 늦은 응답, 재시도, 새로고침 |
| `navigation_test.dart` | 화면 흐름 전체 (FakeTmdbMovieService를 `MovieLogApp(movieService:)`로 주입) |

## 실제 TMDB 로그 (Token 제외)

```
[TMDB 요청] GET https://api.themoviedb.org/3/movie/popular?language=ko-KR&page=1
[TMDB 응답] 200 https://api.themoviedb.org/3/movie/popular?language=ko-KR&page=1

# 목록 진입: Genre + Discover page 1, 2 (20개씩이라 2페이지에서 30개가 찬다)
[TMDB 요청 Query] {language: ko}
[TMDB 요청 Query] {language: ko-KR, page: 1, sort_by: popularity.desc, include_adult: false, include_video: false}
[TMDB 요청 Query] {language: ko-KR, page: 2, sort_by: popularity.desc, include_adult: false, include_video: false}

# 액션 선택: with_genres=28로 page 1부터 다시
[TMDB 요청 Query] {language: ko-KR, page: 1, sort_by: popularity.desc, include_adult: false, include_video: false, with_genres: 28}
[TMDB 요청 Query] {language: ko-KR, page: 2, sort_by: popularity.desc, include_adult: false, include_video: false, with_genres: 28}

# Empty 재현: 존재하지 않는 장르 → total_results 0
[TMDB 응답] 200 .../discover/movie?...&with_genres=999999

# placeholder 재현: 포스터·줄거리가 없는 실제 영화 (Monster, 2027 개봉 예정)
[TMDB 응답] 200 https://api.themoviedb.org/3/movie/1569292?language=ko-KR
```

캡처용으로 `initialLocation`·초기 장르를 잠시 바꿨다가 되돌렸다(커밋에는 없음).
