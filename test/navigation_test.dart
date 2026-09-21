// 3주차 GoRouter 화면 흐름을 실제 AppRouter로 검증하는 Widget 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movielog/home_screen.dart';
import 'package:movielog/movie_detail_screen.dart';
import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/movie_log_app.dart';
import 'package:movielog/my_page_screen.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/sign_up_screen.dart';
import 'package:movielog/widgets/genre_filter_sheet.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/rating_dialog.dart';

void main() {
  // AppRouter.router는 앱 전체에 하나뿐(static)이라 테스트 사이에 위치가 남는다.
  // 각 테스트가 원하는 위치에서 시작하도록 직접 옮긴다.
  Future<void> pumpAppAt(WidgetTester tester, String location) async {
    // 세로가 긴 폰 크기로 고정해 가로 목록·그리드가 화면 안에 들어오게 한다.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MovieLogApp());
    AppRouter.router.go(location);
    await tester.pumpAndSettle();
  }

  // routerDelegate.currentConfiguration.uri는 go로 정한 기준 위치만 돌려주고
  // push로 쌓은 화면은 반영하지 않는다. 맨 위 화면의 위치는 router.state로 읽는다.
  String currentLocation() => AppRouter.router.state.uri.toString();

  testWidgets('시작 → 회원가입 → 홈으로 이어지고, 홈에서는 뒤로 갈 곳이 없다', (
    WidgetTester tester,
  ) async {
    await pumpAppAt(tester, '/start');

    await tester.tap(find.widgetWithText(ElevatedButton, '시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(currentLocation(), '/register');

    await tester.enterText(find.byType(TextFormField).at(0), '태이');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), '12345678');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(currentLocation(), '/home');
    // go로만 이동했으므로 회원가입·시작 화면이 Stack에 남아 있지 않다.
    expect(AppRouter.router.canPop(), isFalse);
  });

  testWidgets('홈 카드를 누르면 Path Parameter로 상세에 가고 pop으로 돌아온다', (
    WidgetTester tester,
  ) async {
    await pumpAppAt(tester, '/home');

    // 대표 카드(별빛 아래 우리, id 1)
    await tester.tap(find.text('오늘의 추천'));
    await tester.pumpAndSettle();

    expect(currentLocation(), '/movies/1');
    expect(find.byType(MovieDetailScreen), findsOneWidget);
    expect(find.text('별빛 아래 우리'), findsOneWidget);
    // 평균 평점 4.5를 읽기 전용으로 표시한다.
    expect(find.text('4.5'), findsOneWidget);
    // 상세는 Shell 밖이라 NavigationBar가 없다.
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(currentLocation(), '/home');
  });

  testWidgets('NavigationBar 탭과 화면, 선택 상태가 일치한다', (WidgetTester tester) async {
    await pumpAppAt(tester, '/home');

    NavigationBar bar() =>
        tester.widget<NavigationBar>(find.byType(NavigationBar));

    await tester.tap(find.text('영화'));
    await tester.pumpAndSettle();
    expect(find.byType(MovieListScreen), findsOneWidget);
    expect(bar().selectedIndex, 1);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(find.byType(MyPageScreen), findsOneWidget);
    expect(bar().selectedIndex, 2);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(bar().selectedIndex, 0);
  });

  testWidgets('장르 Chip을 누르면 Query Parameter가 붙고 목록이 걸러진다', (
    WidgetTester tester,
  ) async {
    await pumpAppAt(tester, '/movies');
    expect(find.byType(MovieCard), findsNWidgets(6));

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    expect(currentLocation(), '/movies?genre=SF');
    expect(find.byType(MovieCard), findsOneWidget);
    expect(find.text('우주의 끝에서'), findsOneWidget);
    // Query가 붙어도 영화 탭이 선택된 상태여야 한다.
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    // 같은 Chip을 다시 누르면 전체로 돌아간다.
    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();
    expect(currentLocation(), '/movies');
    expect(find.byType(MovieCard), findsNWidgets(6));
  });

  testWidgets('필터 BottomSheet에서 장르 두 개를 고르고 확인하면 함께 걸러진다', (
    WidgetTester tester,
  ) async {
    await pumpAppAt(tester, '/movies');

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('장르 필터'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, '드라마'));
    await tester.pump();
    // '액션'은 처음 높이(0.5)에서는 화면 밖이다. 목록을 위로 끌면 Sheet가 먼저 펼쳐지고
    // 그 다음 목록이 스크롤되어 나머지 장르가 보인다.
    await tester.drag(
      find.descendant(
        of: find.byType(GenreFilterSheet),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '액션'));
    await tester.pump();
    // 스크롤해도 확인 버튼은 그대로 보인다.
    expect(find.widgetWithText(ElevatedButton, '2개 장르 적용'), findsOneWidget);
    // 확인 전에는 목록에 반영되지 않는다.
    expect(currentLocation(), '/movies');

    await tester.tap(find.widgetWithText(ElevatedButton, '2개 장르 적용'));
    await tester.pumpAndSettle();

    expect(find.byType(MovieCard), findsNWidgets(2));
    expect(find.text('별빛 아래 우리'), findsOneWidget);
    expect(find.text('밤의 그림자'), findsOneWidget);
  });

  testWidgets('평점 Dialog와 즐겨찾기 Snackbar가 동작한다', (WidgetTester tester) async {
    await pumpAppAt(tester, '/movies/2');
    expect(find.text('우주의 끝에서'), findsOneWidget);

    // 즐겨찾기 추가 → 삭제
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pump();
    expect(find.text('즐겨찾기에서 삭제했습니다.'), findsOneWidget);
    // 떠 있는 Snackbar가 버튼을 가린다. 등장 애니메이션이 끝나야 표시 시간(2초) 타이머가
    // 시작되므로, 먼저 settle한 뒤 시간을 흘려보내고 퇴장 애니메이션까지 다시 settle한다.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에서 삭제했습니다.'), findsNothing);

    // 평점 Dialog: 별을 고르기 전에는 확인이 비활성이다.
    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingDialog), findsOneWidget);
    ElevatedButton confirm() => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '확인'),
    );
    expect(confirm().onPressed, isNull);

    // 세 번째 별의 오른쪽 절반을 눌러 3.0점
    final stars = find.descendant(
      of: find.byType(RatingDialog),
      matching: find.byIcon(Icons.star),
    );
    await tester.tapAt(tester.getCenter(stars.at(2)) + const Offset(8, 0));
    await tester.pump();
    expect(find.text('3.0점'), findsOneWidget);
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingDialog), findsNothing);
    expect(find.text('3.0'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '평점 수정하기'), findsOneWidget);
  });

  testWidgets('없는 영화 ID로 들어오면 안내 화면을 보여준다', (WidgetTester tester) async {
    await pumpAppAt(tester, '/movies/999');
    expect(find.text('영화를 찾을 수 없어요'), findsOneWidget);
  });
}
