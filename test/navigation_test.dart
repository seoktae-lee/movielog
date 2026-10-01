// 5주차 화면 흐름을 실제 AppRouter + Provider로 검증하는 Widget 테스트.
//
// 네트워크 대신 FakeTmdbMovieService를 MovieLogApp에 넣는다.
// 화면(UI Layer)은 이 값이 실제 TMDB 응답인지 fixture인지 모른다.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/home_screen.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/screens/my_page_screen.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/widgets/genre_filter_sheet.dart';
import 'package:movielog/widgets/horizontal_movie_list.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'support/fake_tmdb_movie_service.dart';
import 'support/tmdb_fixtures.dart';

void main() {
  late FakeTmdbMovieService service;

  setUp(() {
    service = FakeTmdbMovieService();
  });

  // AppRouter.router는 앱 전체에 하나뿐(static)이라 테스트 사이에 위치가 남는다.
  // 각 테스트가 원하는 위치에서 시작하도록 직접 옮긴다.
  Future<void> pumpAppAt(WidgetTester tester, String location) async {
    // 세로가 긴 폰 크기로 고정해 가로 목록·그리드가 화면 안에 들어오게 한다.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // 앱을 그리기 전에 위치를 옮겨야 이전 테스트의 화면이 잠깐이라도 만들어지지 않는다.
    AppRouter.router.go(location);
    await tester.pumpWidget(MovieLogApp(movieService: service));
    await tester.pumpAndSettle();
  }

  // push로 쌓은 화면까지 반영된 맨 위 화면의 위치.
  String currentLocation() => AppRouter.router.state.uri.toString();

  testWidgets('시작 → 회원가입 → 홈으로 이어지고, 홈에서는 뒤로 갈 곳이 없다', (tester) async {
    await pumpAppAt(tester, '/start');

    await tester.tap(find.widgetWithText(ElevatedButton, '시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '태이');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), '12345678');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(currentLocation(), '/home');
    expect(AppRouter.router.canPop(), isFalse);
  });

  testWidgets('홈은 Popular 결과 중 5개만 보여 주고, 다시 그려도 요청을 반복하지 않는다', (tester) async {
    await pumpAppAt(tester, '/home');

    // 가로 목록은 화면에 보이는 카드만 만들므로, 목록이 받은 데이터 개수로 확인한다.
    final list = tester.widget<HorizontalMovieList>(
      find.byType(HorizontalMovieList),
    );
    expect(list.movies.map((movie) => movie.id), [100, 101, 102, 103, 104]);

    // 화면을 여러 번 다시 그려도 create(..loadPopular())는 한 번뿐이다.
    await tester.pump();
    await tester.pump();
    expect(service.popularCalls, 1);
  });

  testWidgets('홈 인기 영화가 실패하면 Error와 다시 시도가 보이고, 재시도하면 성공한다', (tester) async {
    var fail = true;
    service.onPopular = (page) async {
      if (fail) throw fakeDioError();
      return TmdbMoviePageDto.fromJson(pageJson([1, 2]));
    };
    await pumpAppAt(tester, '/home');

    expect(find.textContaining('네트워크'), findsOneWidget);

    fail = false;
    await tester.tap(find.widgetWithText(FilledButton, '다시 시도'));
    await tester.pumpAndSettle();
    // 5개보다 적게 와도 범위 오류 없이 있는 만큼 보여 준다.
    expect(
      tester
          .widget<HorizontalMovieList>(find.byType(HorizontalMovieList))
          .movies,
      hasLength(2),
    );
  });

  testWidgets('카드를 누르면 TMDB id로 상세에 가고, 넘겨받은 DTO를 쓰므로 상세 API는 부르지 않는다', (
    tester,
  ) async {
    await pumpAppAt(tester, '/home');

    await tester.tap(find.text('영화 102'));
    await tester.pumpAndSettle();

    expect(currentLocation(), '/movies/102');
    expect(find.byType(MovieDetailScreen), findsOneWidget);
    expect(find.textContaining('movieId 102'), findsOneWidget);
    expect(service.detailCalls, isEmpty);
    // 상세는 Shell 밖이라 NavigationBar가 없다.
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('NavigationBar 탭과 화면, 선택 상태가 일치한다', (tester) async {
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

  testWidgets('영화 목록은 Genre API로 Chip을 만들고 Discover 30개를 보여 준다', (
    tester,
  ) async {
    await pumpAppAt(tester, '/movies');

    expect(find.widgetWithText(ChoiceChip, '전체'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '액션'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '드라마'), findsOneWidget);
    expect(find.text('인기순 30편'), findsOneWidget);
    // 20개씩 오므로 page 1, 2만 요청한다.
    expect(service.discoverCalls.map((call) => call.page), [1, 2]);
    // 카드 아래에 장르 이름과 연도를 표시한다.
    expect(find.text('액션 · 2025'), findsWidgets);
  });

  testWidgets('장르 Chip을 누르면 with_genres로 page 1부터 다시 요청하고, 요청 중엔 Chip이 잠긴다', (
    tester,
  ) async {
    await pumpAppAt(tester, '/movies');
    service.discoverCalls.clear();

    final gate = Completer<void>();
    service.onDiscover = (call) async {
      await gate.future;
      return TmdbMoviePageDto.fromJson(pageJson([1, 2, 3], totalPages: 1));
    };

    await tester.tap(find.widgetWithText(ChoiceChip, '액션'));
    await tester.pump();

    expect(find.byType(MovieListLoading), findsOneWidget);
    expect(service.discoverCalls.single.page, 1);
    expect(service.discoverCalls.single.genreIds, [28]);
    // 요청 중에는 다른 장르를 누를 수 없다.
    final drama = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '드라마'),
    );
    expect(drama.onSelected, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('인기순 3편'), findsOneWidget);
    expect(find.text('액션 · 2025'), findsWidgets);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '액션')).selected,
      isTrue,
    );
  });

  testWidgets('필터 BottomSheet에서 장르 두 개를 고르면 두 id를 함께 보낸다', (tester) async {
    await pumpAppAt(tester, '/movies');
    service.discoverCalls.clear();

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.byType(GenreFilterSheet), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, '드라마'));
    await tester.tap(find.widgetWithText(CheckboxListTile, '액션'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '2개 장르 적용'));
    await tester.pumpAndSettle();

    // 누른 순서와 관계없이 Genre API 순서(액션 28 → 드라마 18)로 보낸다.
    expect(service.discoverCalls.first.genreIds, [28, 18]);
    expect(service.discoverCalls.first.page, 1);
  });

  testWidgets('목록 요청이 실패하면 Error 화면이 보이고 다시 시도하면 Success가 된다', (tester) async {
    var fail = true;
    service.onDiscover = (call) async {
      if (fail) throw fakeDioError(statusCode: 401);
      return TmdbMoviePageDto.fromJson(pageJson([1, 2], totalPages: 1));
    };
    await pumpAppAt(tester, '/movies');

    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.textContaining('인증'), findsOneWidget);

    fail = false;
    await tester.tap(find.widgetWithText(FilledButton, '다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('인기순 2편'), findsOneWidget);
  });

  testWidgets('결과가 없으면 Empty 화면과 전체 보기 버튼이 보인다', (tester) async {
    await pumpAppAt(tester, '/movies');
    service.onDiscover = (call) async =>
        TmdbMoviePageDto.fromJson(pageJson(const [], totalPages: 0));

    await tester.tap(find.widgetWithText(ChoiceChip, '애니메이션'));
    await tester.pumpAndSettle();

    expect(find.text('조건에 맞는 영화가 없어요.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '전체 영화 보기'), findsOneWidget);
  });

  testWidgets('새로고침이 실패하면 목록을 유지한 채 재시도 Dialog를 띄우고, 재시도하면 최신 목록으로 바뀐다', (
    tester,
  ) async {
    await pumpAppAt(tester, '/movies');
    expect(find.text('인기순 30편'), findsOneWidget);

    var fail = true;
    service.onDiscover = (call) async {
      if (fail) throw fakeDioError();
      return TmdbMoviePageDto.fromJson(pageJson([1, 2, 3, 4], totalPages: 1));
    };

    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('영화 목록을 불러오지 못했어요'), findsOneWidget);
    // Dialog 뒤의 목록은 그대로다.
    expect(find.text('인기순 30편'), findsOneWidget);

    fail = false;
    await tester.tap(find.widgetWithText(FilledButton, '재시도'));
    await tester.pumpAndSettle();

    expect(find.text('영화 목록을 불러오지 못했어요'), findsNothing);
    expect(find.text('인기순 4편'), findsOneWidget);
  });

  testWidgets('URL로 상세에 바로 들어오면 movieId로 상세 API를 호출한다', (tester) async {
    await pumpAppAt(tester, '/movies/77');

    expect(service.detailCalls, [77]);
    expect(find.text('상세 77'), findsOneWidget);
  });

  testWidgets('평점 Dialog는 TMDB id를 movieId로 담아 돌려준다', (tester) async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');

    await pumpAppAt(tester, '/movies/550');

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();
    expect(tester.widget<RatingDialog>(find.byType(RatingDialog)).movieId, 550);

    // 세 번째 별의 오른쪽 절반을 눌러 3.0점
    final stars = find.descendant(
      of: find.byType(RatingDialog),
      matching: find.byIcon(Icons.star),
    );
    await tester.tapAt(tester.getCenter(stars.at(2)) + const Offset(8, 0));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();

    // debugPrint는 테스트가 끝나기 전에 되돌려야 한다. (Flutter가 테스트 끝에 검사한다)
    debugPrint = original;
    expect(find.text('3.0점을 남겼습니다.'), findsOneWidget);
    expect(logs, contains('[평점 요청 준비] {movieId: 550, score: 3.0}'));
  });

  testWidgets('포스터 경로가 없으면 placeholder를, 줄거리가 없으면 안내 문구를 보여 준다', (
    tester,
  ) async {
    service.onDetail = (movieId) async => TmdbMoviePageDto.fromJson({
      'results': [
        {
          'id': movieId,
          'title': '정보 없는 영화',
          'overview': '',
          'poster_path': null,
        },
      ],
    }).results.first;

    await pumpAppAt(tester, '/movies/9');

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.text('줄거리 정보가 없어요.'), findsOneWidget);
  });

  testWidgets('숫자가 아닌 영화 ID로 들어오면 안내 화면을 보여준다', (tester) async {
    await pumpAppAt(tester, '/movies/abc');
    expect(find.text('영화를 찾을 수 없어요'), findsOneWidget);
    expect(service.detailCalls, isEmpty);
  });
}
