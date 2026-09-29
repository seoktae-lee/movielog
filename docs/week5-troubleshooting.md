# 5주차 트러블슈팅 (Frontend)

워크북 템플릿(상황 / 호출 API / Query / 기대 / 실제 / ViewModel 상태 / 원인 / 수정 / 재검증) 그대로 적었다.
Token 원문은 어디에도 적지 않는다.

## 1. Token 없이 실행하자 홈이 Error 화면이 됨 (401)

```
상황과 재현 순서: .env의 TMDB_ACCESS_TOKEN을 비운 채 flutter run → 홈 진입
호출 API: Popular (GET /movie/popular)
Query parameter(Token 제외): {language: ko-KR, page: 1}
기대한 상태와 결과 개수: Success, 인기 영화 5개
실제 status / 응답 모양: 401 / {status_code: 7, status_message: Invalid API key: You must be granted a valid key., success: false}
ViewModel 상태: MovieHomeViewModel.status = error, message = "TMDB 인증에 실패했어요. Token 설정을 확인해 주세요."
원인: Authorization 헤더가 "Bearer " 뒤에 값이 없는 상태로 나갔다.
수정: .env.example을 복사해 .env에 Read Access Token(긴 문자열)을 넣는다.
      main.dart에서 Token이 비어 있으면 값은 출력하지 않고 "비어 있어요"만 경고하도록 했다.
재검증: 실제 로그에서 Authorization이 Bearer ***로 가려진 것까지 확인 (아래)
```

실제 콘솔 로그 (iPhone 17 시뮬레이터):

```
[TMDB 설정] TMDB_ACCESS_TOKEN가 비어 있어요. .env.example을 복사해 .env를 만들고 값을 넣어 주세요.
[TMDB 요청] GET https://api.themoviedb.org/3/movie/popular?language=ko-KR&page=1
[TMDB 요청 Header] {Authorization: Bearer ***, accept: application/json}
[TMDB 요청 Query] {language: ko-KR, page: 1}
[TMDB 오류] GET https://api.themoviedb.org/3/movie/popular?language=ko-KR&page=1
[TMDB 오류 Header] {Authorization: Bearer ***, accept: application/json}
[TMDB 오류 내용] badResponse / status 401 / This exception was thrown because the response has a status code of 401 ...
[TMDB 오류 Body] {status_code: 7, status_message: Invalid API key: You must be granted a valid key., success: false}
```

## 2. 상세 화면에서 id만 바꿔 이동하면 이전 영화가 그대로 보임

```
상황과 재현 순서: /movies/77 상세가 떠 있는 상태에서 router.go('/movies/550')
호출 API: 상세 (GET /movie/{id}) — 두 번째 요청이 아예 나가지 않음
Query parameter(Token 제외): {language: ko-KR}
기대한 상태와 결과 개수: movieId 550 영화 1편
실제 status / 응답 모양: 요청 없음. 화면과 평점 Dialog의 movieId가 77
ViewModel 상태: 77번으로 만든 MovieDetailViewModel이 그대로 남아 있음
원인: 같은 GoRoute에서 Path Parameter만 바뀌면 Page·Element가 재사용된다.
      ChangeNotifierProvider의 create는 처음 한 번만 실행되므로 새 id로 ViewModel을 만들지 않았다.
수정: ChangeNotifierProvider에 key: ValueKey(movieId)를 줘서 id가 바뀌면 Provider를 새로 만들게 했다.
재검증: Widget 테스트 "평점 Dialog는 TMDB id를 movieId로 담아 돌려준다"가 550으로 통과
```

평점의 `movieId`가 틀리면 다른 영화에 평점이 저장된다. 워크북이 "index를 movieId로 보내지 말라"고 한 것과 같은 종류의 문제였다.

## 3. 새로고침 실패 Dialog 뒤에서 스피너가 계속 돎

```
상황과 재현 순서: 목록 Success 상태에서 요청이 실패하도록 만든 뒤 당겨서 새로고침
호출 API: Discover
Query parameter(Token 제외): {language: ko-KR, page: 1, sort_by: popularity.desc, include_adult: false, include_video: false}
기대한 상태와 결과 개수: 기존 30개 유지 + 재시도 Dialog
실제 status / 응답 모양: Dialog는 떴지만 뒤의 RefreshIndicator 스피너가 멈추지 않음 (테스트에서는 pumpAndSettle timed out)
ViewModel 상태: status = success, isRefreshing = false (ViewModel은 정상)
원인: onRefresh 안에서 Dialog를 await했다. RefreshIndicator는 onRefresh의 Future가 끝나야 스피너를 숨기는데,
      그 Future가 "사용자가 Dialog를 닫을 때"까지 안 끝났다.
수정: 새로고침은 먼저 끝내고 Dialog는 unawaited로 따로 띄운다.
      Dialog의 재시도는 GlobalKey<RefreshIndicatorState>.show()로 스피너와 함께 다시 시작한다.
재검증: Widget 테스트 "새로고침이 실패하면 … 재시도하면 최신 목록으로 바뀐다" 통과
```

## 4. 홈에 인기 영화 5개가 있는데 테스트에서는 3개만 찾음

```
상황과 재현 순서: Widget 테스트에서 find.byType(TmdbMovieCard) → 5개 기대
호출 API: Popular (fixture)
Query parameter(Token 제외): {language: ko-KR, page: 1}
기대한 상태와 결과 개수: 5
실제 status / 응답 모양: 3개만 찾음
ViewModel 상태: popularMovies.length == 5 (정상)
원인: 가로 ListView.builder는 화면(과 약간의 여유 영역)에 보이는 카드만 만든다. 나머지 2개는 아직 Widget이 없다.
수정: 화면에 그려진 카드 수가 아니라 HorizontalMovieList가 받은 movies(데이터)를 확인하도록 바꿨다.
재검증: 홈 테스트 통과, 받은 id가 [100, 101, 102, 103, 104]로 순서까지 맞음
```

## 5. 장르를 빠르게 바꾸면 이전 장르 결과가 늦게 도착해 덮어쓸 수 있음 (예방)

```
상황과 재현 순서: 액션 요청이 느리게 오는 동안 다른 조건 요청이 먼저 끝나는 상황 (테스트로 재현)
호출 API: Discover (with_genres=28 → with_genres=18)
Query parameter(Token 제외): {page: 1, with_genres: 28} / {page: 1, with_genres: 18}
기대한 상태와 결과 개수: 마지막 조건(18)의 결과만 남음
실제 status / 응답 모양: (수정 전 구조라면) 늦게 온 28번 결과가 18번 결과를 덮어씀
ViewModel 상태: 요청마다 _requestVersion 증가
원인: await 뒤에는 그 사이 더 새로운 요청이 시작됐을 수 있다.
수정: ① 요청마다 version을 올리고, 응답이 왔을 때 version이 다르면 버린다.
      ② 요청 중(isBusy)에는 Chip·필터 버튼을 비활성화하고, ViewModel에서도 selectGenres를 무시한다. (Required 7)
재검증: Unit 테스트 "늦게 도착한 이전 요청의 응답은 버린다", "요청 중에는 장르를 바꿀 수 없다" 통과
```
