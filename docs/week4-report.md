# 4주차 미션 완료 정보 (Frontend)

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/6 |
| 추가한 Package | `shared_preferences 2.5.5` (dev: `shared_preferences_platform_interface` — 테스트용 메모리 저장소) |
| Loading 화면 | `docs/week4-01-loading.png` |
| Success 화면 | `docs/week4-02-success.png` |
| Empty 화면 | `docs/week4-03-empty.png` |
| Error 화면 | `docs/week4-04-error.png` |
| 저장된 장르 복원 화면 | `docs/week4-05-restored-genre.png` (앱 실행 시 저장값 `['SF']` 복원) |
| Error → 재시도 성공 영상 | 노션 제출 페이지에 첨부 (🐞 `첫 시도만 실패` → `다시 시도` → 목록) |
| 앱 재실행 후 장르 복원 영상 | 노션 제출 페이지에 첨부 (캡처는 `week4-05`) |
| Future를 생성한 위치 | `_MovieListScreenState.initState()` / `_retry()` / `_refresh()` / `_changeMode()` — `build` 안에서는 만들지 않음 |
| 사용한 SharedPreferences Key | `selected_genres` (`List<String>`), `movie_sort_option` (`String`, Challenge) |
| `flutter analyze` | `No issues found!` |
| `flutter test` | 25개 통과 (`test/fake_movie_service_test.dart` 6, `test/movie_list_async_test.dart` 7, 기존 12) |
| 트러블슈팅 | `docs/week4-troubleshooting.md` (5건) |
| 캡처 환경 | iPhone 17 시뮬레이터 (iOS 26.1), Flutter 3.47.3 / Dart 3.13.3 |

## 4주차에 추가·수정한 파일

| 파일 | 역할 |
| --- | --- |
| `lib/services/movie_service.dart` | `MovieService` 인터페이스 + `MovieLoadException`. 화면과 데이터 출처 사이의 경계 |
| `lib/services/fake_movie_service.dart` | `Future.delayed`로 성공·빈 목록·실패·지연을 재현하는 Mock Service (`MovieLoadMode`) |
| `lib/services/genre_preference.dart` | 마지막 선택 장르 저장·복원 (`SharedPreferencesAsync`) |
| `lib/services/sort_preference.dart` | 정렬 기준 저장·복원 + `sortMovies()` (Challenge) |
| `lib/models/movie_list_initial_data.dart` | `Future.wait`로 함께 받은 (영화 목록 + 저장된 장르 + 정렬) 묶음 |
| `lib/widgets/movie_grid.dart` | 3주차 목록 화면 안에 있던 GridView를 Success 전용 Widget으로 분리 (+ `RefreshIndicator`) |
| `lib/widgets/movie_list_loading.dart` | Loading 화면. 카드 자리를 미리 보여 주는 Skeleton (Challenge) |
| `lib/widgets/movie_list_empty.dart` | Empty 화면. 안내 문구 + 다음 행동 버튼 |
| `lib/widgets/movie_list_error.dart` | Error 화면. 사용자용 문구 + `다시 시도` 버튼 |
| `lib/movie_list_screen.dart` | StatelessWidget → StatefulWidget. `FutureBuilder`로 네 상태 분기, 저장·복원·재시도·새로고침 |
| `test/fake_movie_service_test.dart` | Mock Service의 성공·빈 목록·실패 Unit 테스트 (Challenge) |
| `test/movie_list_async_test.dart` | Loading·Empty·Error·Success·재시도·장르 저장/복원 Widget 테스트 (Challenge) |

3주차의 `Movie`, `mock_movies.dart`, `MovieCard`, `GenreChips`, `GenreFilterSheet`, 영화 목록 Route는 그대로 재사용했다.

## 비동기 흐름

```
MovieListScreen.initState()
  └ _startLoad()
      ├ _loadInitialData()                     ← Future 생성 지점 (build 아님)
      │   └ Future.wait([
      │       movieService.fetchMovies().timeout(5초),   // 1.2초 Mock 지연
      │       genrePreference.read(),                     // 저장된 장르
      │       sortPreference.read(),                      // 저장된 정렬
      │     ])
      └ _restoreSavedPreferences(future)       ← await 후 mounted 확인 → setState / context.go

FutureBuilder<MovieListInitialData>(future: _initialDataFuture)
  ├ ConnectionState.waiting            → MovieListLoading   (Skeleton)
  ├ snapshot.hasError                  → MovieListError     (다시 시도 버튼)
  ├ data.movies.isEmpty                → MovieListEmpty     ('아직 등록된 영화가 없습니다.')
  ├ 필터 결과가 비었을 때               → MovieListEmpty     ('선택한 장르의 영화가 없습니다.' + 전체 보기)
  └ 그 외                              → MovieGrid          (3주차 MovieCard 재사용)
```

`hasError`를 `data`보다 먼저 확인한다. `ConnectionState.done`이어도 오류로 완료됐을 수 있고, 빈 목록은 오류가 아니라 정상 결과이기 때문이다.

## Future를 만드는 곳과 만들지 않는 곳

| 위치 | 새 Future를 만드는가 | 이유 |
| --- | --- | --- |
| `initState()` | ⭕ 딱 한 번 | 화면이 생길 때 한 번만 요청해야 한다 |
| `_retry()` (다시 시도) | ⭕ | 재시도는 "다시 Loading부터" 시작하는 것 |
| `_changeMode()` (디버그 메뉴) | ⭕ | 다른 결과의 Mock Service로 다시 요청 |
| `_refresh()` (당겨서 새로고침) | ⭕ 단, 직접 `await` | 새로고침 중에는 기존 목록을 그대로 보여 주려고 Future를 즉시 갈아 끼우지 않는다 |
| `build()` | ❌ | Theme 변경·부모 갱신·화면 크기 변경 등으로 여러 번 실행되어 요청이 반복된다 |
| 장르 Chip / 필터 Sheet | ❌ | 필터는 이미 받은 목록을 거르는 일이라 재요청이 필요 없다 (테스트에서 `service.attempt == 1`로 확인) |

## SharedPreferences

| Key | 타입 | 값 | 저장 시점 |
| --- | --- | --- | --- |
| `selected_genres` | `List<String>` | 선택 장르 (`['SF']`, `['드라마','액션']`) | Chip·필터 Sheet로 장르를 바꿀 때 `await save()` |
| `movie_sort_option` | `String` | `latest` \| `rating` \| `title` | 정렬 메뉴를 고를 때 (Challenge) |

- 전체(선택 없음)면 Key를 `remove`해서 "저장된 값 없음 = 전체"로 단순하게 유지한다.
- enum은 그대로 저장할 수 없어 `option.name`(String)으로 바꿔 저장하고, 읽을 때 `values.firstWhere`로 되돌린다. 모르는 값이면 기본값으로 떨어진다.
- 복원은 URL보다 약하다. `/movies?genre=…`처럼 URL이 이미 장르를 들고 있으면(뒤로 가기·Deep Link) 저장값으로 덮어쓰지 않는다.

### 민감한 값을 여기 저장하지 않는 이유

`shared_preferences`는 iOS `NSUserDefaults`, Android `SharedPreferences`에 평문으로 저장되는 **설정 저장소**이지 보안 저장소가 아니다. 탈옥·루팅 기기나 백업 파일에서 그대로 읽힐 수 있다.

- JWT Access/Refresh Token, 비밀번호, 주민등록번호·결제 정보 → `flutter_secure_storage` (iOS Keychain / Android Keystore)
- 4주차에는 로그인·Token이 없어 `flutter_secure_storage`를 추가하지 않았다. Token이 생기는 주차에 도입한다.
- iOS Keychain 값은 **앱을 지웠다 다시 설치해도 남는다.** "앱 삭제 = 자동 로그아웃"을 원하면 `shared_preferences`에 `installation_initialized` 같은 최초 설치 Flag를 두고, 앱 시작 시 Flag가 없으면 `secureStorage.deleteAll()`을 한 번 실행한다. (`shared_preferences`는 앱 삭제와 함께 지워지므로 "Flag가 없다 = 새로 설치됐다"가 성립한다)

## 5주차 교체 지점

- `lib/services/movie_service.dart`: `TODO(5주차 유저별 평점 조회 API)` — Swagger v5의 유저별 평점 조회 API를 호출하는 `RemoteMovieService implements MovieService`를 만든다.
- `lib/movie_list_screen.dart`의 `movieService` 파라미터: `TODO(5주차 유저별 평점 조회 API)` — 넘기는 구현체만 바꾼다.

화면은 `MovieService`가 돌려주는 `Future<List<Movie>>`만 알고 있으므로, Loading·Empty·Error·Success 분기와 재시도 코드는 그대로 두고 Service 구현만 교체하면 된다.

## Required Mission 체크

- [x] 3주차 `Movie`, `MovieCard`, `MovieGrid`(3주차 GridView를 Widget으로 분리) 재사용
- [x] `FakeMovieService.fetchMovies()`가 `Future<List<Movie>>` 반환
- [x] 최소 800ms 이상 Loading — 기본 지연 1,200ms (`fake_movie_service_test.dart`에서 검증)
- [x] Future는 `initState`에서 생성 (`build` 안에서 생성하지 않음)
- [x] Loading·Empty·Error·Success 네 상태 처리
- [x] 오류 화면에 `다시 시도` 버튼
- [x] 재시도할 때만 새 Future 생성
- [x] 내부 Exception·StackTrace는 화면에 노출하지 않음 (`debugPrint`로만 기록하고 `_errorText()`가 사용자 문구로 변환)
- [x] 장르 Chip을 누르면 화면 갱신 (URL Query + 필터)
- [x] 마지막 선택 장르를 `SharedPreferencesAsync`로 저장
- [x] 앱 재실행 시 저장된 장르 복원
- [x] Loading·Empty·Error Widget 각각 분리
- [x] 실제 API·Dio·Retrofit·Provider 미사용
- [x] API 교체 위치에 `TODO(5주차 유저별 평점 조회 API)` 주석
- [x] `flutter analyze` 오류 없음

## Challenge Mission

- [x] `RefreshIndicator`로 당겨서 새로고침 (`MovieGrid.onRefresh`)
- [x] `Future.timeout(5초)` → `TimeoutException`을 "응답이 너무 오래 걸려요." 화면으로 (`MovieLoadMode.timeout`으로 재현)
- [x] CircularProgressIndicator 대신 카드 모양 Skeleton UI (`MovieListLoading`)
- [x] 정렬 방식도 로컬 저장 (`movie_sort_option`, AppBar 정렬 메뉴)
- [x] Mock Service의 성공·빈 목록·실패 Unit Test (`test/fake_movie_service_test.dart`)
- [x] Loading·Empty·Error·Success Widget Test (`test/movie_list_async_test.dart`)

## 캡처·촬영 방법

디버그 빌드의 AppBar 오른쪽 🐞 메뉴(`kDebugMode`에서만 표시)로 Mock 응답을 바꾼다. 메뉴를 고르면 새 Future가 만들어져 Loading부터 다시 시작한다.

| 인증 항목 | 방법 |
| --- | --- |
| Loading | 영화 탭 진입 직후 약 1.2초 (또는 🐞 → 아무 모드 선택 직후) |
| Success | 🐞 → `성공` |
| Empty | 🐞 → `빈 목록` |
| Error | 🐞 → `실패` |
| Error → 재시도 성공 영상 | 🐞 → `첫 시도만 실패` → Error 화면에서 `다시 시도` → 목록 표시 |
| 재실행 후 장르 복원 영상 | 장르 Chip(예: SF) 선택 → 앱 종료 → 다시 실행 → 영화 탭 진입 시 SF가 선택된 상태 |
| 응답 지연(Timeout) | 🐞 → `응답 지연` → 5초 뒤 "응답이 너무 오래 걸려요." |

## 학습 회고

(Backend 워크북까지 끝낸 뒤 학습 자료로 정리하며 채운다)
