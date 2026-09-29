# 5주차 Frontend 노션 제출본 (원고)

> 노션 5주차 Frontend 페이지에 붙여넣는 원고. 워크북 순서 그대로다.
> `🖼️` 표시 자리에 이미지·영상을 드래그한다. **토글 안에 넣지 말 것** (채점에서 빠질 수 있음).
> Token 원문은 이 문서·캡처·영상 어디에도 없어야 한다.

## 📌 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | (PR 링크) |
| 추가 Package | `dio 5.11.1` / `provider 6.1.5+1` / `flutter_dotenv 6.0.1` |
| 검증 | `flutter analyze` 0건 / `flutter test` 50개 통과 |

## 📸 스터디 인증

- [ ] TMDB Token 비노출 확인 — `.env`는 `.gitignore`에 등록, `git log --all -- .env` 결과 없음, 로그는 `Bearer ***`
- [ ] 인기 영화 5개 홈 화면 🖼️ `week5-01-home-popular.png`
- [ ] Discover 최대 30개 목록 화면 🖼️ `week5-02-movies-30.png` ("인기순 30편")
- [ ] 장르 선택 전/후 Network 요청과 목록 변화 영상 🖼️ `5주차영상1.mp4` + 선택 후 캡처 `week5-03-genre-action.png`
- [ ] Loading / Empty / Error / Success 🖼️ `week5-04-loading.png` · `week5-05-empty.png` · `week5-06-error-401.png` · `week5-02-movies-30.png`
- [ ] 포스터 없는 영화의 placeholder 🖼️ `week5-07-placeholder.png`
- [ ] `flutter analyze` 결과와 수동 검증 결과

```
$ flutter analyze
No issues found!

$ flutter test
+50: All tests passed!
```

- [ ] Pull Request와 트러블슈팅 기록 (아래)

## 🎯 핵심 개념

1. **MVVM** — View는 상태를 그리고 입력을 전달만, ViewModel은 화면마다 하나씩 상태(Loading/Success/Empty/Error)와 데이터를 가지며, Model(DTO)은 값만 담는다.
2. **Service Layer** — `TmdbMovieService`는 HTTP 요청과 JSON → DTO 변환만 한다. "5개", "30개", "선택 장르" 같은 화면 정책은 ViewModel이 정한다. 결과를 저장하지 않으니(stateless) 여러 ViewModel이 인스턴스 하나를 같이 쓴다.
3. **UI Layer / Data Layer 분리** — `screens`·`view_models` ↔ `core`·`data`. 테스트는 실제 TMDB 대신 fixture를 돌려주는 Service를 넣었는데 화면 코드는 한 줄도 바뀌지 않았다.
4. **UI에 비즈니스 로직을 넣지 않는 이유** — Widget이 Dio를 직접 부르면 재사용·테스트가 안 되고, 응답 형식이 바뀔 때 Widget을 고쳐야 한다.
5. **.env + .gitignore** — Token은 `.env`에만 두고 커밋에서 제외, `.env.example`로 형식만 공유. 단, 앱 asset에 들어간 값은 배포 앱에서 완전히 숨겨지지 않으므로 운영에서는 백엔드 Proxy를 검토한다.
6. **Dio + Interceptor** — TMDB 전용 Client 하나에 로그 Interceptor를 달아 모든 요청이 같은 형식으로 기록된다. Authorization은 복사본에서 `Bearer ***`로 가리고, `kDebugMode`에서만 등록한다.
7. **DTO 변환** — `poster_path` → `posterPath`처럼 Key를 직접 연결하고, null은 기본값, 숫자는 `num`으로 받아 `toInt()/toDouble()`.
8. **poster_path → 이미지** — `https://image.tmdb.org/t/p/w500` + `poster_path`. null이면 placeholder, 로드 실패도 `errorBuilder`로 placeholder.
9. **ChangeNotifierProvider / Consumer** — Provider는 ViewModel을 만들고 화면이 사라질 때 dispose한다. `context.watch`는 build 전체를, `Consumer`는 builder 범위만 다시 그린다. 버튼 콜백은 `context.read`.
10. **인기 5개** — `take(5)`는 5개보다 적어도 있는 만큼만 돌려줘 RangeError가 없다.
11. **최대 30개** — page 1부터 요청해 `Map<TMDB id, DTO>`에 모으고, 30개·마지막 페이지·빈 페이지에서 멈춘다. 한 페이지 개수(20)는 코드에 적지 않았다.
12. **장르 재조회** — 받은 30개를 로컬에서 거르지 않고 `with_genres`로 page 1부터 다시 요청한다. 늦게 온 옛 응답은 request version으로 버린다.

## 🧪 Guided Practice

- Step 1 — Token 없이 먼저 실행해 **401 로그**와 마스킹을 확인했다(트러블슈팅 1). Token을 넣고 200 확인.
- Step 2 — `TmdbMoviePageDto.fromJson` → `results.take(5)`
- Step 3 — `MovieHomeViewModel`: loading → success/empty/error, `notifyListeners()`
- Step 4 — 홈 1위 카드(backdrop) + 인기 5개 가로 목록을 TMDB 값으로 교체 🖼️ `week5-01-home-popular.png`
- 종료 조건: Popular 요청은 Route의 `create(..loadPopular())`에서 한 번만(테스트로 `popularCalls == 1` 확인), 5개 미만도 OK, 카드가 `movie.id`를 가진다.

## 🚀 Required Mission

- [x] Genre API로 장르 Chip 구성 (id·name 그대로 사용)
- [x] Discover page 1부터 호출
- [x] TMDB id 기준 중복 제거, 최대 30개
- [x] Loading / Empty / Error / Success
- [x] 장르 선택 시 `with_genres`로 page 1부터 재요청
- [x] "전체"는 `with_genres`를 보내지 않음
- [x] 요청 중 장르 변경 불가 (Chip·필터 버튼 비활성 + ViewModel에서도 무시)
- [x] 상세·평점 Dialog로 `TmdbMovieDto.id` 전달 → `CreateRatingRequest(movieId, score)`

```dart
// lib/view_models/movie_list_view_model.dart
Future<List<TmdbMovieDto>> fetchUpToThirtyMovies({List<int>? genreIds}) async {
  final byId = <int, TmdbMovieDto>{};
  var pageNumber = 1;
  var hasNextPage = true;

  while (byId.length < maxMovies && hasNextPage) {
    final page = await _service.discoverMovies(page: pageNumber, genreIds: genreIds);
    for (final movie in page.results) {
      byId[movie.id] = movie;
      if (byId.length == maxMovies) break;
    }
    hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
    pageNumber++;
  }
  return byId.values.take(maxMovies).toList();
}
```

## ⭐ Challenge Mission

- [x] Pull to Refresh — `RefreshIndicator`. 같은 장르로 page 1부터, 기존 목록 유지, Loading 중엔 비활성
- [x] 장르 다중 선택 — 3주차 BottomSheet 재사용, `List<int>` → `with_genres=28|18` (OR)
- [x] 재시도 Dialog — 새로고침 실패 시 목록 유지 + 취소/재시도 🖼️ `week5-08-retry-dialog.png`
- [x] 요청 실패 로그 재현 — Token 없이 401, URL·오류 메시지·Body가 남고 Authorization은 `Bearer ***`
- [ ] release 모드 로그 미출력 확인 (`flutter run --release`)

## 🛠 트러블슈팅

(`docs/week5-troubleshooting.md` 6건을 그대로 붙여넣는다 — 템플릿 형식 유지)

## ✅ 최종 체크리스트

- [x] TMDB와 MovieLog 자체 API의 Client를 분리했습니다. (`createTmdbClient`는 TMDB 전용)
- [x] Token을 코드·Git·로그·영상에 노출하지 않았습니다.
- [x] .env를 .gitignore에 등록했고 커밋되지 않았는지 확인했습니다.
- [x] Popular 결과에서 안전하게 최대 5개를 사용합니다.
- [x] Discover 결과를 TMDB ID 기준 최대 30개로 구성합니다.
- [x] 장르 선택 시 `with_genres`로 다시 요청합니다.
- [x] DTO의 snake_case/null/num 변환을 처리합니다.
- [x] 포스터 null과 로드 실패 화면이 있습니다.
- [x] Loading / Empty / Error / Success와 재시도가 동작합니다.
- [x] 영화 카드의 `id`가 평점 `movieId`로 전달됩니다.
- [x] flutter analyze 통과, 수동 검증 확인

## 📮 제출 양식

```
PR 링크: (PR 링크)
TMDB Token 비노출 확인: .env는 .gitignore 등록·커밋 이력 없음, 로그는 Bearer ***, 캡처·영상에 Token 없음
Popular 5개 화면: week5-01-home-popular.png
Discover 최대 30개 화면과 실제 개수: week5-02-movies-30.png / 30편
Genre API 및 with_genres 요청 증거: 5주차영상1.mp4 + 로그 [TMDB 요청 Query] {..., with_genres: 28}
Loading / Empty / Error / Success: week5-04 / 05 / 06 / 02
포스터 null·실패 처리: TmdbPosterImage (null·빈 문자열·errorBuilder → placeholder), week5-07-placeholder.png
movie.id 전달 위치: context.push('/movies/${movie.id}', extra: movie) → RatingDialog(movieId: movie.id) → CreateRatingRequest
트러블슈팅: 6건
미검증 항목: (있으면 적기)
```

## 🪞 5주차 회고

(학습 세션에서 내 말로 작성)
