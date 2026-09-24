# 3주차 트러블슈팅 기록 (Frontend)

워크북 템플릿(출발 Route / 목적 Route / 사용한 go·push·pop / 전달한 Parameter / 예상한 Back Stack / 실제 동작 / 원인 / 수정 / 재현 및 확인 방법) 형식으로 기록한다.

## 1. 회원가입 Widget 테스트가 `No GoRouter found in context`로 실패

```
출발 Route: /register (SignUpScreen)
목적 Route: /home
사용한 go / push / pop: context.go('/home')
전달한 Parameter: 없음
예상한 Back Stack: [Home] (회원가입 화면 제거)
실제 동작:
  2주차에 만든 테스트가 MaterialApp(home: SignUpScreen())로 화면을 띄운 채
  가입 버튼을 누르자 _submit() 안의 context.go에서
  "No GoRouter found in context" 예외.
원인:
  context.go는 위젯 트리에서 GoRouter(InheritedWidget)를 찾는다.
  MaterialApp.home으로 띄우면 라우터가 없어 찾지 못한다.
수정:
  테스트에서 '/register'와 '/home'만 가진 작은 GoRouter를 만들고
  MaterialApp.router(routerConfig: router)로 띄운다.
  덕분에 "환영 Snackbar 표시 후 홈으로 이동, 회원가입 화면은 사라짐"까지 검증하게 됐다.
재현 및 확인 방법:
  flutter test test/widget_test.dart → "모든 입력이 유효하면 환영 메시지를 표시하고 홈으로 이동한다" 통과.
```

## 2. push한 상세 화면이 떠 있는데 라우터가 알려주는 위치는 여전히 `/home`

```
출발 Route: /home
목적 Route: /movies/1
사용한 go / push / pop: context.push('/movies/1')
전달한 Parameter: Path Parameter movieId = 1
예상한 Back Stack: [MainScreen(/home)] [MovieDetailScreen(/movies/1)]
실제 동작:
  화면에는 MovieDetailScreen이 분명히 떠 있는데(findsOneWidget),
  테스트에서 router.routerDelegate.currentConfiguration.uri를 읽으니 '/home'.
원인:
  currentConfiguration.uri는 go로 정한 기준 위치(URL)를 돌려준다.
  push로 쌓은 화면은 ImperativeRouteMatch로 위에 얹힐 뿐 기준 URL을 바꾸지 않는다.
  "go는 위치를 바꾸고 push는 화면을 쌓는다"가 API에도 그대로 드러난 것.
수정:
  맨 위 화면의 위치는 router.state.uri로 읽는다. push된 상세에서는 '/movies/1',
  Query가 붙은 목록에서는 '/movies?genre=SF'가 그대로 나온다.
재현 및 확인 방법:
  flutter test test/navigation_test.dart → "홈 카드를 누르면 Path Parameter로 상세에 가고 pop으로 돌아온다" 통과.
```

## 3. BottomSheet에서 화면 밖 Checkbox를 누르자 확인 버튼이 눌려 Sheet가 닫힘

```
출발 Route: /movies
목적 Route: /movies?genre=드라마,액션
사용한 go / push / pop: Navigator.pop(sheetContext, selected) → context.go(...)
전달한 Parameter: Query genre
예상한 Back Stack: [MainScreen(/movies)] (Sheet만 닫히고 필터 적용)
실제 동작:
  '드라마'를 체크한 뒤 '액션'을 누르자 Sheet가 닫히고 URL이 ?genre=드라마 로 바뀜.
  '액션'은 initialChildSize 0.5 높이에서는 목록 아래쪽이라 화면 밖.
  테스트가 그 좌표를 눌렀더니 실제로 그 자리에 있던 것은 하단 고정 확인 버튼이었다.
원인:
  ListView.builder는 화면 밖 항목도 cacheExtent만큼 미리 만들어 두므로 finder는 찾지만,
  hit test는 실제 그 좌표의 위젯(확인 버튼)에 맞는다.
  DraggableScrollableSheet는 목록을 끌면 Sheet가 먼저 펼쳐지고 그 다음 목록이 스크롤된다.
수정:
  Sheet 안의 Scrollable을 위로 600px 드래그(Sheet 펼침 + 목록 스크롤)한 뒤 '액션'을 누른다.
  하단 확인 버튼이 스크롤과 무관하게 항상 보이는 것도 이 과정에서 같이 확인했다.
재현 및 확인 방법:
  flutter test test/navigation_test.dart → "필터 BottomSheet에서 장르 두 개를 고르고 확인하면 함께 걸러진다" 통과.
```

## 4. Snackbar 표시 시간(2초)을 흘려보냈는데도 버튼을 가리고 있음

```
출발 Route: /movies/2
목적 Route: (Dialog) RatingDialog
사용한 go / push / pop: showDialog → Navigator.pop(context, rating)
전달한 Parameter: 없음
예상한 Back Stack: [MovieDetailScreen] 위에 Dialog
실제 동작:
  즐겨찾기 Snackbar를 띄운 직후 pump(3초)를 했는데도 '평점 남기기' 버튼 자리의
  hit test 결과가 Snackbar의 텍스트. Dialog가 열리지 않음.
원인:
  ScaffoldMessenger는 Snackbar 등장 애니메이션이 끝난 시점에 duration 타이머를 시작한다.
  pump(3초) 한 번은 프레임 하나만 그리므로, 그 프레임에서 등장이 끝나고 타이머가 '그때부터' 2초.
수정:
  pumpAndSettle() (등장 완료·타이머 시작) → pump(3초) (타이머 만료) → pumpAndSettle() (퇴장 완료)
  순서로 기다린 뒤 버튼을 누른다. 앱 코드는 바꾸지 않았다.
  실제 앱에서도 floating Snackbar가 하단 버튼을 잠시 가리므로 duration을 2초로 짧게 뒀다.
재현 및 확인 방법:
  flutter test test/navigation_test.dart → "평점 Dialog와 즐겨찾기 Snackbar가 동작한다" 통과.
```
