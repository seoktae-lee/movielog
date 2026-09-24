# 4주차 Frontend 노션 제출본

> 노션 4주차 Frontend 페이지에 그대로 붙여넣는 원고. 워크북 순서 그대로다.
> 이미지는 `docs/week4-0*.png`, 영상은 데스크탑 `4주차영상1.mp4`·`4주차영상2.mp4`를 해당 자리에 드래그한다.

## 📌 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/6 |
| 추가 Package | `shared_preferences 2.5.5` |
| 환경 | Flutter 3.47.3 / Dart 3.13.3, iPhone 17 시뮬레이터 |
| 검증 | `flutter analyze` 0건 / `flutter test` 25개 통과 |

## 📸 스터디 인증

- [x] Loading 화면 → `week4-01-loading.png`
- [x] 영화 목록 Success 화면 → `week4-02-success.png`
- [x] Empty 화면 → `week4-03-empty.png`
- [x] Error 화면과 재시도 성공 영상 → `week4-04-error.png` + `4주차영상1.mp4`
- [x] 앱 재실행 후 장르 유지 영상 → `4주차영상2.mp4` + `week4-05-restored-genre.png`
- [x] `flutter analyze` 결과

```
$ flutter analyze
No issues found! (ran in 4.0s)

$ flutter test
00:03 +25: All tests passed!
```

- [x] Pull Request → https://github.com/seoktae-lee/movielog/pull/6

> 네 가지 상태는 디버그 빌드 AppBar의 🐞 메뉴(성공/빈 목록/실패/첫 시도만 실패/응답 지연)로 재현했다.

## 🎯 핵심 개념 (학습 목표 10개)

1. **동기 vs 비동기** — 동기는 앞 작업이 끝나야 다음 줄이 실행되고, 비동기는 결과를 나중에 받는다. 1.2초 기다리는 동안에도 화면은 계속 움직이므로 그 시간을 Loading으로 채운다.
2. **Future / async / await** — `Future<T>`는 "나중에 값 **또는 오류**를 준다"는 약속, `async`는 `await`를 쓸 수 있게 하고, `await`는 그 함수의 다음 줄만 미룬다. `await`를 빼면 값이 아니라 `Future` 자체를 받는다.
3. **try-catch-finally** — `on`으로 예외 타입을 좁히고, `rethrow`로 StackTrace를 유지한 채 다시 던지고, `finally`는 성공·실패와 무관하게 실행된다. 오류는 `debugPrint`로만 기록하고 화면에는 사용자 문구만 보여 준다.
4. **네 가지 상태** — Loading(Skeleton) / Success(MovieGrid) / Empty("아직 등록된 영화가 없습니다") / Error("불러오지 못했습니다" + 다시 시도). **빈 목록은 오류가 아니라 정상 결과**라 문구와 버튼을 다르게 만들었다.
5. **AsyncSnapshot / ConnectionState** — `waiting`이면 Loading, `done`이면 완료(값 또는 오류). `done`이라고 데이터가 있는 게 아니라서 **`hasError` → `data` → 빈 목록** 순으로 확인한다.
6. **build에서 Future를 만들면 안 되는 이유** — `build`는 Theme 변경·부모 갱신·화면 크기 변경으로 여러 번 실행돼 같은 요청이 반복된다. 그래서 `initState`의 필드에 보관한다.
7. **재시도 = 새 Future** — `setState` 안에서 새 Future를 할당해야 `FutureBuilder`가 Loading부터 다시 시작한다. 장르 필터는 이미 받은 목록을 거르는 일이라 새로 만들지 않는다.
8. **mounted** — `await` 뒤에는 화면이 이미 사라졌을 수 있다. `State`에서는 `if (!mounted) return;`, Callback의 context는 `context.mounted`. 안 하면 `setState() called after dispose()`.
9. **shared_preferences** — `int/double/bool/String/List<String>`만 저장 가능해서 장르 문자열과 enum의 `name`만 저장한다. 평문 저장소라 JWT·비밀번호는 `flutter_secure_storage`(Keychain/Keystore)에 저장해야 하고, iOS Keychain은 앱 삭제 후에도 남으므로 최초 설치 Flag로 정리한다.
10. **5주차 교체 구조** — 화면은 `MovieService` 인터페이스만 안다. 5주차엔 `RemoteMovieService`로 구현만 바꾸면 화면 코드는 그대로다. (`TODO(5주차 유저별 평점 조회 API)` 표시)

## 🚀 Required Mission

- [x] 3주차 `Movie` · `MovieCard` · `MovieGrid` 재사용
- [x] `fetchMovies()`가 `Future<List<Movie>>` 반환
- [x] Loading 최소 800ms 이상 (기본 1,200ms)
- [x] Future를 `initState`에서 생성
- [x] Loading·Empty·Error·Success 네 상태 처리
- [x] 오류 화면에 `다시 시도` 버튼
- [x] 재시도할 때만 새 Future 생성
- [x] 내부 Exception·StackTrace 미노출
- [x] 장르 Chip으로 화면 갱신
- [x] 선택 장르를 `SharedPreferencesAsync`로 저장
- [x] 앱 재실행 시 복원
- [x] Loading·Empty·Error Widget 분리
- [x] API·Dio·Retrofit·Provider 미사용
- [x] `TODO(5주차 유저별 평점 조회 API)` 주석
- [x] `flutter analyze` 오류 없음

## ⭐ Challenge Mission

- [x] `RefreshIndicator` 당겨서 새로고침
- [x] `Future.timeout(5초)` → "응답이 너무 오래 걸려요."
- [x] 카드 모양 Skeleton UI
- [x] 정렬 방식도 로컬 저장 (`movie_sort_option`)
- [x] Mock Service Unit Test 6개
- [x] 네 상태 Widget Test 7개

## 🛠 트러블슈팅 (5건)

**1. 테스트가 `SharedPreferencesAsyncPlatform instance must be set`로 실패**
`shared_preferences`는 Plugin이라 `flutter test`에는 구현이 없다. `setUp`에서 `InMemorySharedPreferencesAsync`로 바꿔 끼워 해결. 덕분에 "저장값이 있으면 복원된다" 테스트까지 작성했다.

**2. 당겨서 새로고침이 기존 목록을 Skeleton으로 덮음**
`future`를 바로 갈아 끼우면 `FutureBuilder`가 `waiting`으로 돌아간다. 새로고침은 직접 `await` → `mounted` 확인 → 완료된 Future로 교체, 실패는 Snackbar로만. 재시도 버튼은 반대로 일부러 Loading부터.

**3. 장르를 바꿀 때 Loading이 반복되지 않는지 확인**
장르를 URL Query로 관리해서 걱정했는데, go_router의 Page Key가 `matchedLocation('/movies')`이라 Query가 바뀌어도 State가 유지된다. `expect(service.attempt, 1)` 테스트로 고정했다.

**4. 저장된 장르 복원이 URL을 덮어쓸 뻔함**
`/movies?genre=드라마`로 들어온 경우까지 저장값으로 바뀌면 안 된다. 복원 조건을 "URL에 장르가 없을 때"로 제한하고, 복원 이동에서는 다시 저장하지 않도록 했다.

**5. Empty·Error를 재현할 수 없어 캡처 불가**
Mock이 항상 성공하면 두 화면을 볼 수 없다. `MovieLoadMode`와 🐞 메뉴(`kDebugMode` 전용)를 추가했고, `첫 시도만 실패` 모드로 "Error → 다시 시도 → 성공"을 한 번에 촬영했다.

## ✅ 최종 체크리스트

- [x] Future는 값 또는 오류로 완료된다 (`hasError`를 먼저 확인)
- [x] async 함수 반환 타입을 `Future<T>`로 작성
- [x] try-catch-finally 역할 구분 (`on` / `rethrow` / 항상 실행)
- [x] Future를 build 안에서 생성하지 않음
- [x] AsyncSnapshot·ConnectionState 설명 가능
- [x] 네 화면 상태 모두 확인
- [x] 오류 화면에서 재시도 동작 (영상 1)
- [x] await 후 setState 전 `mounted` 확인
- [x] 앱 재실행 후 장르 복원 (영상 2)
- [x] 민감한 값은 저장하지 않음
- [x] JWT·비밀번호는 `flutter_secure_storage` (평문 저장소가 아니므로)
- [x] iOS 재설치 시 최초 설치 Flag로 Keychain 정리 흐름 설명 가능
- [x] 네트워크 패키지 미추가
- [x] PR에 네 상태 화면·영상 첨부

## 📮 제출 양식

```
이름 / 닉네임: 이석태 / 태이
GitHub 저장소: https://github.com/seoktae-lee/movielog
Pull Request: https://github.com/seoktae-lee/movielog/pull/6
Loading 화면: week4-01-loading.png (Skeleton UI)
Empty 화면: week4-03-empty.png
Error 및 재시도 영상: 4주차영상1.mp4
Success 화면: week4-02-success.png
Future를 생성한 위치: initState() / _retry() / _refresh() / _changeMode() (build 아님)
사용한 SharedPreferences Key: selected_genres, movie_sort_option
앱 재실행 후 복원 영상: 4주차영상2.mp4
발생한 오류와 해결 과정: 위 트러블슈팅 5건
4주차 회고: 아래
```

## 🪞 4주차 회고

(초안 — 내 말로 다듬어서 제출)

화면을 "데이터가 있다/없다"가 아니라 **네 가지 상태**로 나눠 보게 된 게 가장 큰 변화였다. 특히 Empty와 Error는 둘 다 목록이 안 보이는 화면이지만, 빈 목록은 정상 결과고 오류는 다시 시도할 수 있는 상황이라 필요한 문구와 버튼이 달랐다.

`build`에서 Future를 만들면 안 되는 이유는 새로고침을 만들다가 체감했다. Future를 새로 만든다는 건 곧 화면을 Loading부터 다시 시작한다는 뜻이어서, 재시도에는 맞지만 새로고침에는 맞지 않았다.

3주차에 장르를 URL Query로 관리해 둔 것과 로컬 저장이 충돌할 뻔한 것도 기억에 남는다. 상태를 어디에 둘지뿐 아니라 **누가 우선인지**까지 정해야 한다는 걸 배웠다.

5주차에는 Mock Service를 실제 API로 바꾼다. 화면이 `MovieService` 인터페이스만 알도록 경계를 그어 뒀으니, 이번에 만든 Loading·Empty·Error 화면이 그대로 재사용되는지 확인해 보고 싶다.
