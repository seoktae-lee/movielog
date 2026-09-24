# 3주차 미션 완료 정보 (Frontend)

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/5 |
| 사용한 go_router 버전 | `go_router 18.0.1` (`flutter_rating_bar 4.0.1`) |
| 홈 화면 | `docs/week3-01-home.png` |
| 영화 목록 화면 | `docs/week3-02-movies.png` |
| 영화 상세 화면 | `docs/week3-03-detail.png` |
| 마이페이지 | `docs/week3-04-my.png` |
| NavigationBar 탭 전환 영상 | (촬영 후 PR에 첨부) |
| 목록 → 상세 → 뒤로 영상 | (촬영 후 PR에 첨부) |
| Dialog / BottomSheet / Snackbar 실행 화면 | (촬영 후 PR에 첨부) |
| 트러블슈팅 | `docs/week3-troubleshooting.md` (4건) |

## Route 목록

| 경로 | 화면 | 위치 | 비고 |
| --- | --- | --- | --- |
| `/start` | `StartScreen` | 최상위 | `initialLocation` |
| `/register` | `SignUpScreen` | 최상위 | `PopScope(canPop: false)`로 뒤로 가기 차단 |
| `/home` | `HomeScreen` | `ShellRoute` 안 | `MainScreen`이 NavigationBar 담당 |
| `/movies` | `MovieListScreen` | `ShellRoute` 안 | Query `?genre=드라마,SF`로 필터 |
| `/my` | `MyPageScreen` | `ShellRoute` 안 | 1주차 프로필 위젯 재사용 |
| `/movies/:movieId` | `MovieDetailScreen` | 최상위 | Shell 밖이라 NavigationBar 없음, `push`로 진입 |

`ShellRoute`의 `builder`가 `MainScreen(currentIndex: indexFromLocation(state.uri.path), child: child)`를 돌려주고, `MainScreen`이 `Scaffold`와 `NavigationBar`를 한 번만 만든다. 탭 세 화면은 `body`(`child`)만 바뀐다.

## go / push / pop 사용 위치

| 메서드 | 위치 | 이유 |
| --- | --- | --- |
| `context.go('/register')` | `start_screen.dart` 시작하기 버튼 | 시작 화면으로 돌아올 필요 없음 |
| `context.go('/home')` | `sign_up_screen.dart` `_submit()` | 가입 완료 후 회원가입 화면이 Stack에 남으면 안 됨 |
| `context.go('/home' \| '/movies' \| '/my')` | `main_screen.dart` `onDestinationSelected` | 탭 전환은 위치 자체를 바꾸는 것. push면 탭을 누를 때마다 Stack이 쌓임 |
| `context.go('/movies')` | `home_screen.dart` 전체보기 | 탭 화면 사이 이동 |
| `context.go(Uri(path: '/movies', queryParameters: ...))` | `movie_list_screen.dart` `_applyGenres()` | 장르 필터를 URL에 반영 |
| `context.push('/movies/${movie.id}')` | `home_screen.dart`, `movie_list_screen.dart`, `my_page_screen.dart` 카드 `onTap` | 상세를 보고 원래 목록으로 돌아와야 하므로 push |
| `context.pop()` | `movie_detail_screen.dart` `_goBack()` | push로 왔으면 pop. `canPop()`이 false(URL 직접 진입)면 `go('/home')` |
| `Navigator.pop(context, value)` | `rating_dialog.dart`, `genre_filter_sheet.dart` | Dialog·BottomSheet는 GoRouter Route가 아니라 Navigator 위의 임시 Route라 `Navigator.pop`으로 닫으며 값을 돌려줌 |

## Path Parameter 사용 위치

- 선언: `GoRoute(path: '/movies/:movieId', ...)` — `app_router.dart`
- 읽기: `int.tryParse(state.pathParameters['movieId'] ?? '')` → `MovieDetailScreen(movieId: ...)`
- 사용: `findMovieById(widget.movieId)` — 없으면 `null` → `_MovieNotFound` 화면
- `':movieId'`의 이름과 `pathParameters['movieId']`의 Key가 같아야 한다.

## Query Parameter와 Extra 비교

| | Query Parameter | Extra |
| --- | --- | --- |
| 용도 | 검색어·필터·정렬 같은 **선택적 화면 조건** | 이미 가진 **객체를 그대로** 넘길 때 |
| URL에 남는가 | 남는다 (`/movies?genre=SF`) | 남지 않는다 |
| 앱 재시작·URL 직접 접근·Deep Link | 값이 살아 있다 | 값이 없다 (`state.extra`가 null) |
| 타입 | 문자열 (직접 파싱) | 아무 객체 (`as Movie?` 캐스팅) |
| 이번 주 사용 | 장르 필터 `?genre=드라마,SF` (Challenge) | 사용하지 않음. 상세는 Path Parameter ID로 Mock을 다시 찾음 |

Extra만 믿으면 `/movies/1`을 직접 열었을 때 영화가 없다. 그래서 상세는 ID → `findMovieById`를 기본으로 두었다.

## Dialog / BottomSheet / Snackbar 사용 위치

| 종류 | 위치 | 내용 |
| --- | --- | --- |
| Dialog | `movie_detail_screen.dart` `_openRatingDialog()` → `RatingDialog` | `showDialog<double>`, `MovieRatingInput`(`RatingBar.builder`)으로 0.5 단위 선택. 별을 고르기 전엔 확인 비활성, 초기화 버튼(Challenge) |
| BottomSheet | `movie_list_screen.dart` `_openFilterSheet()` → `GenreFilterSheet` | `showModalBottomSheet<Set<String>>` + `DraggableScrollableSheet(0.3~0.9)`. Checkbox 다중 선택, 목록만 스크롤, 확인 버튼 하단 고정, 확인 전엔 목록에 반영 안 함 (Challenge) |
| Snackbar | `movie_detail_screen.dart` `_toggleFavorite()`, `_openRatingDialog()` | 즐겨찾기 추가/삭제, 평점 저장 안내. `floating`, 연타 시 `hideCurrentSnackBar()` 후 표시 |
| Snackbar | `sign_up_screen.dart` `_submit()` | 가입 환영 메시지 후 `go('/home')` |

## 화면 구조와 분리한 Widget

```
MaterialApp.router (routerConfig: AppRouter.router)
 ├ /start      StartScreen
 ├ /register   SignUpScreen (PopScope canPop:false)
 ├ ShellRoute  MainScreen (PopScope canPop:false, Scaffold + NavigationBar)
 │   ├ /home     HomeScreen
 │   │   ├ FeaturedMovieCard            ← GestureDetector → push
 │   │   ├ SectionHeader('지금 인기') + HorizontalMovieList (ListView.separated)
 │   │   └ SectionHeader('최근 개봉') + HorizontalMovieList
 │   ├ /movies   MovieListScreen (Stateless, 선택 장르는 URL이 소유)
 │   │   ├ AppBar action: filter_list → GenreFilterSheet (BottomSheet)
 │   │   ├ GenreChips (ListView.separated, ChoiceChip)
 │   │   └ GridView.builder (2열, childAspectRatio 0.6) → MovieCard
 │   └ /my       MyPageScreen
 │       ├ ProfileHeader / ProfileStats / FavoriteGenres (1주차 재사용)
 │       ├ SectionHeader('즐겨찾기한 영화') + HorizontalMovieList
 │       └ EditProfileButton
 └ /movies/:movieId  MovieDetailScreen (Stateful: _isFavorite, _myRating)
     ├ CommonAppBar(onBack, 즐겨찾기 IconButton → Snackbar)
     ├ _MovieDetailHeader (포스터, 제목, 장르·연도, MovieAverageRating = RatingBarIndicator 4.5)
     ├ 줄거리 (Mock 문장)
     └ _MyRatingSection (내 평점 + 평점 남기기 → RatingDialog → Snackbar)
```

새로 분리한 공통 Widget 9개: `MovieCard`, `SectionHeader`, `HorizontalMovieList`, `FeaturedMovieCard`, `GenreChips`, `GenreFilterSheet`, `MovieRatingInput`, `MovieAverageRating`, `RatingDialog`

## 상태가 어디에 있는가

| 상태 | 소유자 | 이유 |
| --- | --- | --- |
| 선택 장르 | URL Query (`/movies?genre=…`) | 화면을 다시 만들어도 유지, 뒤로 가기·Deep Link와 자연스럽게 맞물림 |
| BottomSheet 안 체크 상태 | `_GenreFilterSheetState._selected` | 확인 전까지는 Sheet 안에서만 바뀌어야 함 |
| 즐겨찾기 여부, 내 평점 | `_MovieDetailScreenState` | 8주차 API 전까지는 화면 내부 상태로만 |
| Dialog 안 별점 | `_RatingDialogState._rating` | 확인을 눌러야 `Navigator.pop`으로 부모에게 전달 |

## Required Mission 체크

- [x] 홈, 영화 목록, 영화 상세, 마이페이지 구현
- [x] 동일한 Material 3 Theme(`AppTheme.light`)와 Mock Data(`lib/data/mock_movies.dart`)
- [x] NavigationBar로 홈·영화·마이 전환 (`ShellRoute` + `go`)
- [x] GestureDetector로 카드 Tap (`MovieCard`, `FeaturedMovieCard`)
- [x] Path Parameter로 상세 이동 / Route ID로 Mock Movie 표시 / 뒤로 가기
- [x] ListView(가로 목록·Chip 줄)와 GridView(영화 목록) 사용
- [x] 장르 Chip 필터
- [x] 평점 남기기 → `MovieRatingInput` Dialog
- [x] 즐겨찾기 추가·삭제 Snackbar + 아이콘 변경
- [x] 의미 단위 Widget 4개 이상 분리 (9개)
- [x] API·인증·Provider·MVVM 미사용, 평점·즐겨찾기는 화면 내부 상태
- [x] `flutter analyze` 오류 없음, `flutter test` 12개 통과

## Challenge Mission

- [x] Query Parameter로 선택 장르를 URL에 표현
- [x] 필터 아이콘 → `DraggableScrollableSheet` BottomSheet, Checkbox 다중 선택, 목록만 스크롤, 확인 버튼 고정, 확인 시 적용, 빈 선택은 전체
- [x] 평점 Dialog 초기화·다시 선택 (`_resetCount`로 `RatingBar` 재생성)
- [ ] `StatefulShellRoute.indexedStack` — 상세 화면을 Shell 밖 전체 화면으로 두는 설계를 택해 탭별 Stack 보존이 필요 없었음. 4주차 이후 탭 안에 하위 화면이 생기면 전환 검토

## 학습 회고

(Backend 워크북까지 끝낸 뒤 학습 자료로 정리하며 채운다)
