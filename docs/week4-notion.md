# 4주차 Frontend 노션 제출본

> 노션 **4주차 Frontend 개인 미션 페이지**에 그대로 붙여넣기 위한 원고다.
> 워크북 순서(스터디 인증 → 학습 목표 → Required → Challenge → 트러블슈팅 → 최종 체크리스트 → 제출 양식)를 그대로 따른다.
> 이미지는 `docs/week4-0*.png`를, 영상은 데스크탑의 `4주차영상1.mp4`·`4주차영상2.mp4`를 해당 위치에 드래그해 넣는다.

---

## 📌 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/6 |
| 추가한 Package | `shared_preferences 2.5.5` (테스트용 dev: `shared_preferences_platform_interface`) |
| 실행 환경 | Flutter 3.47.3 / Dart 3.13.3, iPhone 17 시뮬레이터 (iOS 26.1) |
| 산출물 | `docs/week4-report.md`, `docs/week4-troubleshooting.md`(5건), 화면 캡처 5장 |
| 검증 | `flutter analyze` 오류 0건 / `flutter test` 25개 통과 |

---

## 📸 스터디 인증

- [x] **Loading 화면** — `week4-01-loading.png` 드래그
- [x] **영화 목록 Success 화면** — `week4-02-success.png` 드래그
- [x] **Empty 화면** — `week4-03-empty.png` 드래그
- [x] **Error 화면과 재시도 성공 영상** — `week4-04-error.png` + `4주차영상1.mp4` 드래그
- [x] **앱을 재실행해도 마지막 선택 장르가 유지되는 영상** — `4주차영상2.mp4` + `week4-05-restored-genre.png` 드래그
- [x] **`flutter analyze` 결과**

```
$ flutter analyze
Analyzing movielog...
No issues found! (ran in 4.0s)

$ flutter test
00:03 +25: All tests passed!
```

- [x] **Pull Request 링크** — https://github.com/seoktae-lee/movielog/pull/6

> 네 가지 상태는 디버그 빌드 AppBar의 🐞 메뉴(`kDebugMode`에서만 표시)로 재현했다.
> `성공 / 빈 목록 / 실패 / 첫 시도만 실패 / 응답 지연` 다섯 가지 Mock 응답을 고를 수 있게 만들었고,
> 특히 `첫 시도만 실패`는 "Error → 다시 시도 → 성공"을 한 번에 촬영하려고 넣었다.

---

## 🎯 핵심 개념 정리

> 워크북 학습 목표 10개에 1:1로 답하는 형태로 정리했다. 전부 이번 주차 내 코드에서 실제로 쓴 내용이다.

### 1. 동기 처리와 비동기 처리의 차이

동기 코드는 앞 작업이 **끝나야** 다음 줄이 실행된다. 비동기 코드는 네트워크 요청·로컬 저장소 읽기처럼 **언제 끝날지 알 수 없는 작업**의 결과를 나중에 전달한다.

핵심은 "기다리는 동안 앱이 멈추지 않는다"는 점이다. `FakeMovieService`가 1.2초를 기다리는 동안에도 장르 Chip은 스크롤되고 탭 전환도 된다. 그래서 그 시간을 빈 화면이 아니라 **Loading 상태**로 채워 줘야 한다.

### 2. `Future<T>` / `async` / `await`의 역할 구분

| 키워드 | 역할 |
| --- | --- |
| `Future<T>` | "지금은 없지만, 나중에 `T` 값 **또는 오류**를 준다"는 약속. 결과는 단 한 번 |
| `async` | 이 함수 안에서 `await`를 쓸 수 있게 하고, 반환값을 `Future`로 감싼다 |
| `await` | 그 `Future`가 완료될 때까지 **현재 함수의 다음 줄만** 미룬다 (앱 전체가 멈추는 게 아니다) |

`await` 없이 호출하면 값이 아니라 `Instance of 'Future<List<Movie>>'`를 받는다. 실제로 `_loadInitialData()`에서 `await`를 빼면 `results[0] as List<Movie>` 캐스팅에서 바로 터진다.

반환 타입도 `void`가 아니라 `Future<void>`로 명시했다. `void loadMovies() async {}`로 두면 호출한 쪽에서 완료를 기다릴 수도, 오류를 잡을 수도 없다.

### 3. `try-catch-finally`로 비동기 오류 처리

```dart
try {
  final results = await Future.wait([...]);
  return MovieListInitialData(...);
} on MovieLoadException catch (error, stackTrace) {
  debugPrint('영화 로드 실패: $error');       // 개발자용 기록
  debugPrintStack(stackTrace: stackTrace);
  rethrow;                                   // StackTrace를 유지한 채 다시 던진다
} on TimeoutException catch (error) {
  debugPrint('영화 로드 시간 초과: $error');
  rethrow;
} finally {
  debugPrint('영화 로드 시도 종료');          // 성공·실패와 무관하게 실행
}
```

- `on`으로 처리할 예외 타입을 좁히고, `rethrow`로 **화면에 보여 줄 판단은 `FutureBuilder`에 맡긴다.**
- 화면에는 `MovieLoadException`, `TimeoutException`, StackTrace를 그대로 쓰지 않고 `_errorText()`가 만든 사용자 문구만 보여 준다.

### 4. Loading · Empty · Error · Success 네 가지 상태

| 상태 | 의미 | 내 화면 |
| --- | --- | --- |
| Loading | 아직 완료되지 않음 | 카드 자리를 미리 그리는 Skeleton + "영화를 불러오는 중이에요" |
| Success | 값으로 완료 + 목록 있음 | 3주차 `MovieCard`를 쓰는 `MovieGrid` |
| Empty | 값으로 완료 + 목록 없음 | "아직 등록된 영화가 없습니다." + `다시 불러오기` / 필터 결과가 없으면 "선택한 장르의 영화가 없습니다." + `전체 영화 보기` |
| Error | 오류로 완료 | "영화 목록을 불러오지 못했습니다." + `다시 시도` |

**Empty는 오류가 아니다.** 그래서 아이콘·문구·다음 행동을 Error와 다르게 만들었고, Empty를 두 종류(서버가 빈 목록 / 내 필터 결과가 빈 목록)로 나눠 사용자가 원인을 알 수 있게 했다.

### 5. `AsyncSnapshot`과 `ConnectionState`

| `ConnectionState` | 의미 | 표시 |
| --- | --- | --- |
| `none` | `future`가 null | (이 화면에서는 발생하지 않음. 항상 Future를 넘김) |
| `waiting` | 연결됐지만 미완료 | Loading |
| `active` | 값이 계속 오는 중 | `StreamBuilder`에서 주로 봄 |
| `done` | 값 **또는 오류**로 완료 | Success / Empty / Error 중 하나 |

`done`이라고 데이터가 있는 게 아니다. 그래서 순서를 **`hasError` → `data` → 빈 목록 여부**로 확인한다. 이 순서를 뒤집으면 "오류가 났는데 Empty 화면이 뜨는" 흔한 버그가 난다.

### 6. `build` 안에서 `Future`를 만들면 안 되는 이유

`build`는 Theme 변경·부모 Widget 갱신·화면 크기 변경·키보드 등장 등 **여러 이유로 다시 실행된다.** `future: movieService.fetchMovies()`처럼 쓰면 그때마다 새 요청이 나가고 Loading이 반복된다.

그래서 Future는 `initState`의 필드(`_initialDataFuture`)에 보관한다.

### 7. 재시도 = 새로운 `Future` 생성

```dart
void _retry() {
  setState(() {
    _initialDataFuture = _startLoad();   // 새 Future → 다시 waiting부터
  });
}
```

`setState` 안에서 **새 Future를 할당**해야 `FutureBuilder`가 바뀐 걸 알아채고 Loading부터 다시 시작한다. 반대로 장르 Chip은 이미 받은 목록을 거르는 일이라 새 Future를 만들지 않는다. (테스트에서 `expect(service.attempt, 1)`로 고정)

### 8. `mounted`를 확인해야 하는 상황

요청이 끝나기 전에 사용자가 화면을 떠나면 `State`는 이미 `dispose`된 상태다. 그때 `setState`를 부르면 `setState() called after dispose()`가 난다.

- `State` 안: `if (!mounted) return;`
- Callback에서 받은 `BuildContext`: `if (!context.mounted) return;`
- **`await` 뒤**에서 `setState`·`context`를 쓸 때만 필요하고, async gap이 없으면 필요 없다.

내 코드에서는 `_restoreSavedPreferences()`(저장값 복원), `_refresh()`(새로고침), `_applyGenres()`(저장 후 `context.go`), `_changeSort()`에서 확인한다.

### 9. `shared_preferences` — 저장해도 되는 값과 안 되는 값

| Key | 타입 | 값 |
| --- | --- | --- |
| `selected_genres` | `List<String>` | 마지막 선택 장르 |
| `movie_sort_option` | `String` | 정렬 기준 (`latest` / `rating` / `title`) |

- 지원 타입은 `int`, `double`, `bool`, `String`, `List<String>`뿐이라 `Movie` 객체는 저장할 수 없다. 장르 문자열, enum의 `name`처럼 **단순한 값으로 바꿔서** 저장한다.
- 새 코드 권장 API인 `SharedPreferencesAsync`를 썼다. 읽기까지 전부 비동기다.
- **보안 저장소가 아니다.** 평문으로 저장되므로 JWT Access/Refresh Token, 비밀번호, 개인정보는 `flutter_secure_storage`(iOS Keychain / Android Keystore)에 저장해야 한다.
- iOS Keychain 값은 **앱을 삭제해도 남는다.** "앱 삭제 = 자동 로그아웃"을 원하면 `shared_preferences`에 `installation_initialized` 같은 최초 설치 Flag를 두고, 앱 시작 시 Flag가 없으면 `secureStorage.deleteAll()`을 한 번 실행한다. (`shared_preferences`는 앱과 함께 지워지므로 "Flag 없음 = 새로 설치됨"이 성립한다)

### 10. 5주차에 실제 API로 교체할 수 있는 구조

```dart
abstract interface class MovieService {
  Future<List<Movie>> fetchMovies();
}

class FakeMovieService implements MovieService { ... }   // 4주차
// TODO(5주차 유저별 평점 조회 API): RemoteMovieService implements MovieService
```

화면은 `MovieService`가 돌려주는 `Future<List<Movie>>`만 안다. Mock인지 실제 API인지 모르기 때문에, 5주차에는 **Service 구현만 바꾸면** Loading·Empty·Error·Success 분기와 재시도 코드는 그대로 둘 수 있다.

---

## 🚀 Required Mission 체크

- [x] 3주차 `Movie`, `MovieCard`, `MovieGrid` 재사용 (목록 화면 안의 GridView를 `MovieGrid` Widget으로 분리)
- [x] `FakeMovieService.fetchMovies()`가 `Future<List<Movie>>` 반환
- [x] 최소 800ms 이상 Loading — 기본 지연 **1,200ms** (Unit 테스트로 800ms 이상 검증)
- [x] Future를 `build`가 아닌 `initState`에서 생성
- [x] Loading·Empty·Error·Success 네 상태 처리
- [x] 오류 화면에 `다시 시도` 버튼 배치
- [x] 재시도할 때만 새로운 Future 생성
- [x] 내부 Exception·StackTrace를 화면에 노출하지 않음 (`debugPrint`로만 기록)
- [x] 장르 Chip을 누르면 화면 갱신 (URL Query `?genre=SF` + 필터)
- [x] 마지막 선택 장르를 `SharedPreferencesAsync`로 저장
- [x] 앱을 다시 실행하면 저장된 장르 복원 (영상 2)
- [x] Loading·Empty·Error Widget 각각 분리 (`movie_list_loading/empty/error.dart`)
- [x] 실제 API·Dio·Retrofit·Provider 미사용
- [x] API 교체 위치에 `TODO(5주차 유저별 평점 조회 API)` 주석
- [x] `flutter analyze` 오류 없음

---

## ⭐ Challenge Mission

- [x] `RefreshIndicator`로 당겨서 새로고침 — 새로고침 중에는 기존 목록을 유지한다
- [x] `Future.timeout(5초)` → `TimeoutException`을 "응답이 너무 오래 걸려요." 화면으로 (🐞 `응답 지연`으로 재현)
- [x] `CircularProgressIndicator` 대신 영화 카드 형태의 **Skeleton UI**
- [x] 장르뿐 아니라 **정렬 방식**(최신순/평점순/가나다순)도 로컬 저장
- [x] `FakeMovieService`의 성공·빈 목록·실패 **Unit Test** 6개
- [x] Loading·Empty·Error·Success **Widget Test** 7개

---

## 🛠 트러블슈팅 기록

> 저장소 원본: `docs/week4-troubleshooting.md` (5건 전체)

### 1. 3주차 테스트가 `SharedPreferencesAsyncPlatform instance must be set`로 실패

```
재현 상태: Loading (화면이 그려지자마자 예외)
사용한 MovieLoadMode: success
기대한 결과: 3주차 네비게이션 테스트가 그대로 통과
실제 결과: 목록 화면이 StatefulWidget이 되면서 initState에서 저장값을 읽자마자 테스트 중단
발생한 Exception: Bad state: The SharedPreferencesAsyncPlatform instance must be set.
Future를 생성한 위치: initState() → _startLoad() → _loadInitialData()
mounted 확인 여부: 해당 없음 (생성 단계에서 실패)
SharedPreferences Key: selected_genres
원인: shared_preferences는 Plugin이라 실제 기기에는 구현이 붙지만 flutter test에는 없다.
수정: setUp에서 SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()
      (dev_dependencies에 shared_preferences_platform_interface 추가)
      덕분에 withData로 값을 심어 "앱 재실행 후 복원" 테스트까지 작성할 수 있었다.
재현 및 확인 방법: setUp을 지우면 재현. 되돌리면 flutter test 25개 통과.
```

### 2. 당겨서 새로고침을 하면 기존 목록이 Skeleton으로 덮임

```
재현 상태: Success → 당겨서 새로고침
기대한 결과: 새로고침 중에도 기존 목록이 보이고, 끝나면 목록만 갱신
실제 결과: setState로 새 Future를 바로 할당했더니 FutureBuilder가 waiting으로 돌아가
          Loading Skeleton이 화면을 덮고 RefreshIndicator를 단 MovieGrid까지 사라짐
Future를 생성한 위치: _refresh() — 문제의 지점
setState 호출 위치: _refresh() 안, await 이후
mounted 확인 여부: 확인함 (if (!mounted) return;)
원인: FutureBuilder는 future가 바뀌면 이전 snapshot을 버리고 waiting부터 다시 시작한다.
      "재시도(처음부터)"에는 맞지만 "새로고침(현재 화면 유지)"에는 맞지 않는다.
수정: 새로고침은 직접 await → mounted 확인 → 이미 완료된 Future(Future.value)로 교체.
      실패는 화면을 Error로 덮지 않고 Snackbar로만 알린다.
      반대로 '다시 시도' 버튼은 의도적으로 새 Future를 만들어 Loading부터 시작한다.
재현 및 확인 방법: 목록에서 아래로 당기기 → 목록 유지된 채 갱신.
```

### 3. 장르 Chip을 누를 때마다 다시 Loading이 뜨지 않는지 확인

```
재현 상태: Success → 장르 Chip 선택
기대한 결과: 필터는 이미 받은 목록을 거르는 일이므로 재요청 없음
걱정한 것: 이 화면은 장르를 URL Query로 관리해서 Chip을 누르면 context.go로 URL이 바뀐다.
          State가 새로 만들어지면 initState가 다시 돌아 Loading이 반복된다.
확인 내용: go_router는 Page Key를 matchedLocation('/movies')으로 만든다.
          Query가 달라져도 Key가 같아 State가 유지되고 initState는 다시 호출되지 않는다.
          눈으로 보는 대신 테스트로 고정: expect(service.attempt, 1);
Future를 생성한 위치: initState()
mounted 확인 여부: _applyGenres에서 저장을 await한 뒤 확인
SharedPreferences Key: selected_genres
재현 및 확인 방법: flutter test → "장르 Chip을 누르면 선택 장르가 저장되고, 영화를 다시 부르지는 않는다" 통과.
```

### 4. 저장된 장르 복원이 URL의 장르를 덮어쓸 뻔함

```
재현 상태: Loading → Success (앱 재실행 직후)
기대한 결과: 저장값은 복원하되, URL이 이미 장르를 들고 있으면 URL이 이긴다
실제 결과: 복원을 무조건 적용하면 /movies?genre=드라마로 들어온 경우(뒤로 가기·Deep Link)에도
          저장값(SF)으로 덮어써서 방금 요청한 화면이 바뀐다
setState 호출 위치: _restoreSavedPreferences() 안, await 이후 (정렬 복원)
mounted 확인 여부: 확인함. await 뒤 if (!mounted) return; 이후에만 setState·context.go 사용
SharedPreferences Key: selected_genres, movie_sort_option
수정: 복원 조건을 "URL에 장르가 없을 때"로 제한하고,
      복원 이동에서는 다시 저장하지 않도록 _applyGenres(..., persist: false)로 호출
재현 및 확인 방법: flutter test → "저장된 장르가 있으면 앱을 다시 켰을 때 그 장르로 복원된다" 통과.
                 기기에서도 확인 (docs/week4-05-restored-genre.png, 영상 2)
```

### 5. Empty·Error 화면을 재현할 방법이 없어 인증 캡처를 못 찍음

```
재현 상태: Empty, Error
사용한 MovieLoadMode: empty, failure, failFirst
실제 결과: Mock Service가 항상 성공하면 Empty·Error는 코드에만 존재하고 화면으로는 볼 수 없다.
          테스트로는 검증되지만 스터디 인증 캡처를 찍을 수 없다.
Future를 생성한 위치: _changeMode() — 모드를 바꾸면 새 Future를 만들어 Loading부터 시작
mounted 확인 여부: 불필요 (await 이후가 아님)
수정: MovieLoadMode(success/empty/failure/failFirst/timeout)와 AppBar 🐞 메뉴 추가.
      kDebugMode에서만 보이므로 배포 빌드에는 들어가지 않는다.
      failFirst는 "첫 시도만 실패"라 Error → 다시 시도 → 성공 영상을 한 번에 찍을 수 있다.
재현 및 확인 방법: 디버그 실행 → 🐞 → 빈 목록 / 실패 / 첫 시도만 실패 / 응답 지연.
```

---

## ✅ 최종 체크리스트

- [x] **Future가 값 또는 오류로 완료될 수 있음을 설명할 수 있다** — `done`이어도 데이터가 없을 수 있어 `hasError`를 먼저 본다
- [x] **async 함수의 반환 타입을 `Future<T>`로 작성했다** — `Future<void> _applyGenres(...)`, `Future<MovieListInitialData> _loadInitialData()`
- [x] **try-catch-finally의 역할을 구분할 수 있다** — `on`으로 타입 좁히기, `rethrow`로 StackTrace 유지, `finally`는 항상 실행
- [x] **Future를 build 안에서 생성하지 않았다** — `initState`·`_retry`·`_refresh`·`_changeMode`에서만 생성
- [x] **AsyncSnapshot과 ConnectionState를 설명할 수 있다** — `waiting` → Loading, `done` → Success/Empty/Error 분기
- [x] **Loading·Empty·Error·Success 화면을 모두 확인했다** — 캡처 4장 첨부
- [x] **오류 화면에서 재시도가 동작한다** — 영상 1
- [x] **직접 await 후 setState를 호출하는 경우 mounted를 확인했다** — `_refresh`, `_restoreSavedPreferences`, `_changeSort`
- [x] **마지막 선택 장르가 앱 재실행 후 복원된다** — 영상 2
- [x] **민감한 값을 shared_preferences에 저장하지 않았다** — 장르·정렬만 저장
- [x] **JWT와 비밀번호를 flutter_secure_storage에 저장해야 하는 이유를 설명할 수 있다** — `shared_preferences`는 평문 설정 저장소, Keychain/Keystore는 OS 암호화 저장소
- [x] **iOS 재설치 시 최초 설치 Flag로 이전 Secure Storage 값을 정리하는 흐름을 설명할 수 있다** — Keychain은 앱 삭제 후에도 남으므로 `installation_initialized` Flag가 없을 때 `deleteAll()`
- [x] **실제 네트워크 패키지를 추가하지 않았다** — `shared_preferences`만 추가
- [x] **Pull Request에 네 상태의 화면 또는 영상을 첨부했다** — PR #6

---

## 📮 제출 양식

```
이름 / 닉네임: 이석태 / 태이
GitHub 저장소: https://github.com/seoktae-lee/movielog
Pull Request: https://github.com/seoktae-lee/movielog/pull/6
Loading 화면: docs/week4-01-loading.png (Skeleton UI)
Empty 화면: docs/week4-03-empty.png
Error 및 재시도 영상: 4주차영상1.mp4 (🐞 첫 시도만 실패 → 다시 시도 → 성공)
Success 화면: docs/week4-02-success.png
Future를 생성한 위치: _MovieListScreenState.initState() / _retry() / _refresh() / _changeMode()
                     (build 안에서는 생성하지 않음)
사용한 SharedPreferences Key: selected_genres (List<String>), movie_sort_option (String)
앱 재실행 후 복원 영상: 4주차영상2.mp4 (SF 선택 → 앱 종료 → 재실행 → SF 유지)
발생한 오류와 해결 과정: 위 트러블슈팅 5건 참고
4주차 회고: 아래
```

---

## 🪞 4주차 회고

(초안 — 내 말로 다듬어서 제출)

이번 주차에서 가장 크게 바뀐 건 "데이터가 있다/없다"로만 보던 화면을 **네 가지 상태로 나눠 보게 된 것**이다. 특히 Empty와 Error를 구분하는 게 중요했다. 둘 다 "목록이 안 보이는 화면"이라 처음엔 하나로 묶고 싶었는데, 빈 목록은 정상 결과이고 오류는 사용자가 다시 시도할 수 있는 상황이라 필요한 문구와 버튼이 완전히 달랐다. `hasError`를 `data`보다 먼저 확인해야 하는 이유도 여기서 이해됐다.

`build` 안에서 Future를 만들면 안 되는 이유는 글로 읽을 때보다 직접 겪을 때 와닿았다. 새로고침을 구현하면서 `setState`로 Future를 바로 갈아 끼웠더니 화면이 통째로 Loading으로 돌아가 버렸다. "Future를 새로 만든다 = 화면을 Loading부터 다시 시작한다"는 뜻이라, 재시도에는 맞지만 새로고침에는 맞지 않았다. 결국 재시도는 새 Future를, 새로고침은 직접 `await` 후 완료된 Future로 교체하는 식으로 나눴다.

`shared_preferences`는 쓰는 것 자체는 간단했지만, 3주차에 장르를 URL Query로 관리해 둔 것과 충돌할 뻔했다. 저장값을 무조건 복원하면 `/movies?genre=드라마`로 들어온 사용자의 화면까지 덮어쓰게 돼서, 복원을 "URL에 장르가 없을 때만"으로 제한했다. 상태를 어디에 둘지(URL / State / 로컬 저장소) 정하고, **누가 우선인지까지 정해야** 한다는 걸 배웠다.

테스트에서 `SharedPreferencesAsyncPlatform instance must be set` 오류를 만난 것도 기억에 남는다. Plugin은 실제 기기에서만 구현이 붙는다는 걸 처음 알았고, 메모리 저장소로 바꿔 끼우는 방법을 익힌 덕분에 "저장된 장르가 있으면 복원된다"는 시나리오까지 테스트로 고정할 수 있었다.

5주차에는 `FakeMovieService`를 실제 API Service로 바꾼다. 화면이 `MovieService` 인터페이스만 알도록 경계를 그어 뒀으니, 이번에 만든 Loading·Empty·Error 화면이 그대로 재사용되는지 확인해 보고 싶다.
