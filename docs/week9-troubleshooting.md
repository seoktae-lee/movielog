# 9주차 Frontend 트러블슈팅

각 항목은 이슈 / 문제 / 해결 순서다.

## No.1 마이페이지에 행을 추가하자 프로필 수정 테스트 3개가 깨짐

- **이슈**: `navigation_test`의 프로필 수정 테스트에서 `Expected: '/my/profile/edit' Actual: '/movies'`.
- **문제**: "내 즐겨찾기" 행이 늘어나 `프로필 수정` 버튼이 하단 NavigationBar 쪽으로 밀렸다. `scrollUntilVisible`은 일부만 보여도 멈춰서, 탭이 NavigationBar의 "영화" 탭에 닿았다.
- **해결**: 스크롤 뒤에 `ensureVisible`로 완전히 보이게 한 다음 탭하도록 테스트를 고쳤다.

## No.2 `MovieGrid`에 footer를 붙이려니 GridView로는 불가능

- **이슈**: 카드 아래에 "더 보기·추가 로딩·재시도·끝" 한 줄을 붙여야 하는데 `GridView.builder`는 카드 외의 위젯을 아래에 붙이기 어렵다.
- **문제**: 5주차 목록은 `GridView` 하나였다.
- **해결**: `CustomScrollView` + `SliverGrid` + `SliverToBoxAdapter(footer)`로 바꿨다. `RefreshIndicator`는 그대로 감싼다. 이 때문에 테스트의 `find.byType(GridView)`를 `CustomScrollView`로 바꿨다.

## No.3 다음 page 실패 뒤 재시도 버튼이 화면 밖으로 밀림

- **이슈**: 실패 문구가 한 줄 늘어 재시도 버튼이 화면 아래로 밀려, 테스트가 탭해도 반응이 없었다(`[1, 2]` 기대 `[1, 2, 2]`).
- **문제**: footer가 커지면 버튼 위치가 바뀐다.
- **해결**: 탭 전에 `ensureVisible`을 호출했다. 앱에서는 사용자가 스크롤하면 되므로 코드 변경은 없다.

## No.4 평점 중복(409)을 Dialog 안에 둘지 닫을지

- **이슈**: 8주차에는 모든 저장 실패가 Dialog 안 문구였다. 9주차 Challenge는 `RATING409_1`·`FAVORITE409_1`·`MEMBER404_1`은 닫고 Snackbar, `COMMON400`·네트워크 실패는 열어 두라고 한다.
- **문제**: 다시 눌러도 소용없는 오류(이미 저장됨)에서 Dialog를 열어 두면 사용자가 같은 요청을 반복한다.
- **해결**: `onSubmit`이 `RatingSubmitClosed`를 던지면 Dialog가 그 값을 반환하며 닫히게 했다. 호출부가 Snackbar로 안내한다. 입력을 고쳐 다시 시도할 수 있는 오류는 기존대로 일반 예외라 Dialog가 열린 채 별점·코멘트를 유지한다.

## No.5 오래 두면 실제로 401이 나서 로그인 화면으로 돌아감

- **이슈**: 실서버 검증 중 하루가 지나자 `GET /v8/favorites`가 401이었고 앱이 로그인 화면으로 이동했다.
- **문제**: 토큰이 만료됐다. (코드 오류가 아니라 의도한 동작)
- **해결**: 조치할 것은 없다. 8주차의 세션 만료 처리(`AUTH401_2/3/4` → 세션 한 번 정리 → 로그인)가 즐겨찾기 요청에도 그대로 동작함을 실제로 확인했다. 검증 중 만든 즐겨찾기 일부는 해제하지 못한 채 남았다(재로그인 후 정리 필요).

## No.6 워크북 예제와 다르게 한 점

- `PagedMoviesViewModel`: 워크북 예제는 단일 장르(`int? genreId`)지만 5주차 Challenge의 다중 선택(`List<int>`)을 유지했다. `with_genres`는 `|`(OR)로 잇는다.
- `refresh`(당겨서 새로고침): 워크북은 조건 변경 때만 초기화하지만, 5주차 기능을 유지하려고 기존 목록을 보여 주다 성공하면 교체하는 `refresh()`를 추가했다.
- `FavoritesViewModel`: 워크북은 실패 카드 재조회가 전체 `refresh()`지만, "그 카드만 다시 조회"하도록 `retryMovie`를 추가했다.
- 세션 만료: 두 ViewModel에 `AuthViewModel`을 넘겨, 요청을 **보낼 때**의 `sessionVersion`으로 `expireSession`을 호출한다. 이전 계정에서 늦게 도착한 401이 현재 계정을 로그아웃시키지 않는다.
