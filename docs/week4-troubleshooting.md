# 4주차 트러블슈팅 기록 (Frontend)

워크북 템플릿(재현 상태 / 사용한 MovieLoadMode / 기대한 결과 / 실제 결과 / 발생한 Exception / Future를 생성한 위치 / setState 호출 위치 / mounted 확인 여부 / SharedPreferences Key / 수정 내용 / 재현 및 확인 방법) 형식으로 기록한다.

## 1. 3주차 Widget 테스트가 `SharedPreferencesAsyncPlatform instance must be set`로 실패

```
재현 상태: Loading (화면이 그려지자마자 터짐)
사용한 MovieLoadMode: success
기대한 결과: 3주차 네비게이션 테스트가 그대로 통과
실제 결과:
  영화 목록 화면이 StatefulWidget이 되면서 initState에서 저장값을 읽자마자
  테스트가 예외로 중단됐다.
발생한 Exception:
  Bad state: The SharedPreferencesAsyncPlatform instance must be set.
    #0 new SharedPreferencesAsync (shared_preferences_async.dart:25:7)
    #1 new GenrePreference (genre_preference.dart:12:37)
    #2 _MovieListScreenState._loadInitialData (movie_list_screen.dart:103)
Future를 생성한 위치: initState() → _startLoad() → _loadInitialData()
setState 호출 위치: 해당 없음 (생성 단계에서 실패)
mounted 확인 여부: 해당 없음
SharedPreferences Key: selected_genres
원인:
  shared_preferences는 Plugin이다. 실제 기기에서는 iOS NSUserDefaults / Android
  SharedPreferences 구현이 붙지만, flutter test에는 그 구현(Platform 인스턴스)이 없다.
수정:
  테스트 setUp에서 메모리 저장소로 바꿔 끼운다.
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  (dev_dependencies에 shared_preferences_platform_interface 추가)
  덕분에 "저장된 장르가 있으면 복원된다" 테스트를 withData로 미리 값을 넣어 작성할 수 있었다.
재현 및 확인 방법:
  setUp을 지우고 flutter test → 위 예외. 되돌리면 flutter test 25개 통과.
```

## 2. 당겨서 새로고침을 하면 기존 목록이 Skeleton으로 덮여 버림

```
재현 상태: Success → 당겨서 새로고침
사용한 MovieLoadMode: success
기대한 결과: 새로고침이 도는 동안 기존 목록이 그대로 보이고, 끝나면 목록만 갱신
실제 결과:
  _refresh()에서 setState로 _moviesFuture에 새 Future를 바로 할당했더니
  FutureBuilder가 ConnectionState.waiting으로 돌아가 Loading Skeleton이 화면을 덮고,
  RefreshIndicator를 달고 있던 MovieGrid 자체가 사라졌다.
발생한 Exception: 없음 (동작만 어색함)
Future를 생성한 위치: _refresh() — 문제의 지점
setState 호출 위치: _refresh() 안, await 이후
mounted 확인 여부: 확인함 (if (!mounted) return;)
SharedPreferences Key: 해당 없음
원인:
  FutureBuilder는 future가 바뀌면 이전 snapshot을 버리고 waiting부터 다시 시작한다.
  "재시도(=처음부터 다시)"에는 맞지만 "새로고침(=지금 화면 유지)"에는 맞지 않는다.
수정:
  새로고침은 Future를 즉시 갈아 끼우지 않고 직접 await한 뒤,
  mounted를 확인하고 이미 완료된 Future(Future.value(data))로 교체한다.
  실패하면 화면을 Error로 덮지 않고 Snackbar로만 알린다.
  반대로 '다시 시도' 버튼은 의도적으로 새 Future를 만들어 Loading부터 시작한다.
재현 및 확인 방법:
  영화 목록에서 아래로 당기기 → 목록이 유지된 채 위쪽 새로고침 표시만 돌고 갱신됨.
```

## 3. 장르 Chip을 누를 때마다 다시 1.2초 Loading이 뜨지 않는지 확인

```
재현 상태: Success → 장르 Chip 선택
사용한 MovieLoadMode: success
기대한 결과: 필터는 이미 받은 목록을 거르는 일이므로 재요청이 없어야 한다
실제 결과(확인 전 걱정한 것):
  이 화면은 장르를 URL Query(/movies?genre=SF)로 관리한다. Chip을 누르면 context.go로
  URL이 바뀌므로, 화면 State가 새로 만들어지면 initState가 다시 돌아 Loading이 반복된다.
발생한 Exception: 없음
Future를 생성한 위치: initState()
setState 호출 위치: 해당 없음 (URL만 바뀜)
mounted 확인 여부: _applyGenres에서 저장을 await한 뒤 확인함
SharedPreferences Key: selected_genres
확인 내용:
  go_router는 Page Key를 matchedLocation('/movies')으로 만든다. Query가 달라져도 Key가
  같아서 Element와 State가 그대로 유지되고, initState는 다시 호출되지 않는다.
  눈으로 확인하는 대신 테스트로 고정했다.
    expect(service.attempt, 1);            // Chip을 누른 뒤에도 요청 횟수 1
    expect(find.byType(MovieListLoading), findsNothing);
재현 및 확인 방법:
  flutter test test/movie_list_async_test.dart
  → "장르 Chip을 누르면 선택 장르가 저장되고, 영화를 다시 부르지는 않는다" 통과.
```

## 4. 저장된 장르 복원이 URL의 장르를 덮어쓸 뻔함

```
재현 상태: Loading → Success (앱 재실행 직후)
사용한 MovieLoadMode: success
기대한 결과: 저장된 장르가 복원되지만, URL이 이미 장르를 들고 있으면 URL이 이긴다
실제 결과(설계 중 발견):
  복원을 무조건 적용하면 /movies?genre=드라마로 들어온 경우(뒤로 가기, Deep Link)에도
  저장값(SF)으로 덮어써서 사용자가 방금 요청한 화면이 바뀌어 버린다.
발생한 Exception: 없음
Future를 생성한 위치: initState() → _startLoad()
setState 호출 위치: _restoreSavedPreferences() 안, await 이후 (정렬 복원)
mounted 확인 여부: 확인함. await 뒤 if (!mounted) return; 이후에만 setState·context.go 사용
SharedPreferences Key: selected_genres, movie_sort_option
수정:
  복원 조건을 "URL에 장르가 없을 때(widget.selectedGenres.isEmpty)"로 제한했다.
  복원으로 이동할 때는 저장을 다시 하지 않도록 _applyGenres(..., persist: false)로 부른다.
  (저장값을 읽어서 바로 다시 저장하는 쓸데없는 쓰기를 막는다)
재현 및 확인 방법:
  flutter test test/movie_list_async_test.dart
  → "저장된 장르가 있으면 앱을 다시 켰을 때 그 장르로 복원된다" 통과.
  기기: main()에서 GenrePreference().save({'SF'})로 값을 심고 실행 →
        영화 탭 진입 시 SF Chip이 선택된 상태 (docs/week4-05-restored-genre.png)
```

## 5. Empty·Error 화면을 재현할 방법이 없어 인증 캡처를 못 찍음

```
재현 상태: Empty, Error
사용한 MovieLoadMode: empty, failure, failFirst
기대한 결과: 네 가지 상태를 원할 때 화면에서 바로 재현
실제 결과:
  Mock Service가 항상 성공하면 Empty·Error 화면은 코드에만 존재하고
  실제로 볼 수가 없다. 테스트로는 검증되지만 스터디 인증 캡처를 찍을 수 없다.
발생한 Exception: 해당 없음
Future를 생성한 위치: _changeMode() — 모드를 바꾸면 새 Future를 만들어 Loading부터 다시 시작
setState 호출 위치: _changeMode() 안 (동기, async gap 없음)
mounted 확인 여부: 불필요 (await 이후가 아님)
SharedPreferences Key: 해당 없음
수정:
  MovieLoadMode(success / empty / failure / failFirst / timeout)와
  AppBar의 🐞 메뉴를 추가했다. kDebugMode에서만 보이므로 배포 빌드에는 들어가지 않는다.
  특히 failFirst는 "첫 시도만 실패"라서 Error → 다시 시도 → 성공 영상을 한 번에 찍을 수 있다.
재현 및 확인 방법:
  디버그 실행 → AppBar 🐞 → 빈 목록 / 실패 / 첫 시도만 실패 / 응답 지연 선택.
  캡처: docs/week4-01-loading.png, -02-success.png, -03-empty.png, -04-error.png
```
