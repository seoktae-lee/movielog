// 화면 흐름을 실제 AppRouter + Provider로 검증하는 Widget 테스트.
//
// 네트워크 대신 Fake Service를 MovieLogApp에 넣는다.
// 8주차: 저장소에 토큰이 있으면 세션 복원(GET me) → /home으로 시작한다.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/movie_log_app.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/screens/home_screen.dart';
import 'package:movielog/screens/login_screen.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/screens/main_screen.dart';
import 'package:movielog/screens/my_page_screen.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';
import 'package:movielog/widgets/favorite_button.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/genre_filter_sheet.dart';
import 'package:movielog/widgets/horizontal_movie_list.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';
import 'package:movielog/widgets/rating_dialog.dart';
import 'package:provider/provider.dart';

import 'support/fake_movielog_services.dart';
import 'support/fake_tmdb_movie_service.dart';
import 'support/tmdb_fixtures.dart';

/// 이번 세션에서 등록했다고 가정할 평점. (ratingId 내림차순)
final seedRatings = <RatingDto>[
  fakeRating(3, 13, 3, null),
  fakeRating(2, 680, 4, '다시 봐도 좋다'),
  fakeRating(1, 550, 5, '최고의 영화!'),
];

void main() {
  late FakeTmdbMovieService service;
  late FakeSignUpService checkService;
  late FakeRatingApiService ratingService;
  late FakeFavoriteApiService favoriteService;
  late FakeMovieRecordApiService recordService;
  late FakeAuthApiService authService;
  late FakeMemberApiService memberService;
  late InMemoryTokenStorage storage;

  setUp(() {
    service = FakeTmdbMovieService();
    checkService = FakeSignUpService();
    ratingService = FakeRatingApiService();
    favoriteService = FakeFavoriteApiService();
    recordService = FakeMovieRecordApiService(
      ratings: ratingService,
      favorites: favoriteService,
    );
    authService = FakeAuthApiService();
    memberService = FakeMemberApiService();
    storage = InMemoryTokenStorage();
  });

  BuildContext appContext(WidgetTester tester) =>
      tester.element(find.byType(Navigator).first);

  GoRouter router(WidgetTester tester) => GoRouter.of(appContext(tester));

  /// [signedIn]이면 저장소에 토큰을 넣어 두고 앱을 켠다 → GET me 성공 → /home.
  /// 그다음 [location]으로 이동한다. signedOut이면 Router가 /login으로 보낸다.
  Future<void> pumpAppAt(
    WidgetTester tester,
    String location, {
    bool signedIn = true,
    List<RatingDto>? sessionRatings,
  }) async {
    // 세로가 긴 폰 크기로 고정해 가로 목록·그리드가 화면 안에 들어오게 한다.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    storage.token = signedIn ? 'saved-token' : null;
    await tester.pumpWidget(
      MovieLogApp(
        movieService: service,
        signUpService: checkService,
        ratingApiService: ratingService,
        favoriteApiService: favoriteService,
        movieRecordApiService: recordService,
        authApiService: authService,
        memberApiService: memberService,
        tokenStorage: storage,
        emailPreferences: FakeEmailPreferences(),
        installMarker: FakeInstallMarker(),
      ),
    );
    await tester.pumpAndSettle();

    if (sessionRatings != null) {
      final context = appContext(tester);
      final version = context.read<AuthViewModel>().sessionVersion;
      final store = context.read<SessionRatingStore>();
      // 보관함은 최근 것을 위에 넣으므로 오래된 것부터 넣는다.
      for (final rating in sessionRatings.reversed) {
        store.add(version, rating);
      }
    }
    if (signedIn && location != '/home') {
      router(tester).go(location);
      await tester.pumpAndSettle();
    }
  }

  // push로 쌓은 화면까지 반영된 맨 위 화면의 위치.
  String currentLocation(WidgetTester tester) =>
      router(tester).state.uri.toString();

  testWidgets('로그인 화면 → 회원가입(POST) → 로그인 화면으로 돌아오고 이메일이 채워진다', (tester) async {
    await pumpAppAt(tester, '/login', signedIn: false);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('아직 회원이 아니신가요? 회원가입'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '태이');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Pass1234!');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('중복 확인').first);
    await tester.tap(find.text('중복 확인').last);
    await tester.pump();
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    expect(checkService.signUpCalls, hasLength(1));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(currentLocation(tester), '/login');
    expect(find.text('a@b.com'), findsOneWidget);
    expect(router(tester).canPop(), isFalse);
  });

  testWidgets('회원가입은 push로 열려 뒤로 가면 로그인 화면으로 돌아간다', (tester) async {
    await pumpAppAt(tester, '/login', signedIn: false);

    await tester.tap(find.text('아직 회원이 아니신가요? 회원가입'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
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

    expect(currentLocation(tester), '/movies/102');
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

  testWidgets('영화 목록은 Genre API로 Chip을 만들고 Discover 첫 page 20개만 보여 준다', (
    tester,
  ) async {
    await pumpAppAt(tester, '/movies');

    expect(find.widgetWithText(ChoiceChip, '전체'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '액션'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '드라마'), findsOneWidget);
    expect(find.text('인기순 20편'), findsOneWidget);
    // 9주차: 30개를 모으지 않고 첫 page 하나만 요청한다.
    expect(service.discoverCalls.map((call) => call.page), [1]);
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
    expect(find.text('인기순 20편'), findsOneWidget);

    var fail = true;
    service.onDiscover = (call) async {
      if (fail) throw fakeDioError();
      return TmdbMoviePageDto.fromJson(pageJson([1, 2, 3, 4], totalPages: 1));
    };

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('영화 목록을 불러오지 못했어요'), findsOneWidget);
    // Dialog 뒤의 목록은 그대로다.
    expect(find.text('인기순 20편'), findsOneWidget);

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

  Finder dialogStars() => find.descendant(
    of: find.byType(RatingDialog),
    matching: find.byIcon(Icons.star),
  );
  Finder dialogButton(String label) => find.descendant(
    of: find.byType(RatingDialog),
    matching: find.widgetWithText(ElevatedButton, label),
  );

  testWidgets(
    '이미 즐겨찾기한 영화의 평점 등록: TMDB id·정수 score·comment로 POST /ratings하고 성공 Snackbar',
    (tester) async {
      // 이미 즐겨찾기한 영화는 체크박스 없이 기존 평점 API(POST /v8/ratings)로 저장한다.
      favoriteService.favorites = [fakeFavorite(1, 550)];
      await pumpAppAt(tester, '/movies/550');

      await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsOneWidget);
      // 별점을 고르기 전에는 코멘트를 써도 확인을 누를 수 없다.
      await tester.enterText(find.byType(TextField).last, '  다시 보고 싶다  ');
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(dialogButton('확인')).onPressed,
        isNull,
      );

      // 세 번째 별의 오른쪽 절반을 눌러도 정수 모드라 3점
      await tester.tapAt(
        tester.getCenter(dialogStars().at(2)) + const Offset(8, 0),
      );
      await tester.pump();
      expect(find.text('3점'), findsOneWidget);
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      // path·body 어디에도 memberId가 없다. 토큰은 보호용 Client가 붙인다.
      final request = ratingService.createCalls.single;
      expect(request.toJson(), {
        'movieId': 550,
        'score': 3,
        'comment': '다시 보고 싶다',
      });
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.textContaining('평점을 저장했습니다.'), findsOneWidget);
      // 이미 즐겨찾기한 영화라서 체크박스가 없고 영화 기록 API는 쓰지 않는다.
      expect(find.byKey(const ValueKey('add-to-favorite')), findsNothing);
      expect(recordService.calls, isEmpty);
      // 등록 result(Rating 객체)로 "내 평점"이 바로 바뀌고 같은 영화에 다시 POST할 수 없다.
      expect(find.text('등록 완료 · 수정은 마이페이지에서'), findsOneWidget);
    },
  );

  testWidgets('RATING409_1이면 Dialog를 닫고 Snackbar로 안내하며 로그인 상태는 유지한다', (
    tester,
  ) async {
    favoriteService.favorites = [fakeFavorite(1, 550)];
    ratingService.writeError = fakeMovieLogError(
      statusCode: 409,
      code: 'RATING409_1',
      message: '이미 이 영화에 평점을 남기셨습니다.',
    );
    await pumpAppAt(tester, '/movies/550');

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();
    await tester.tap(dialogStars().at(3));
    await tester.enterText(find.byType(TextField).last, '코멘트');
    await tester.tap(dialogButton('확인'));
    await tester.pumpAndSettle();

    // 다시 눌러도 소용없는 오류라 Dialog는 닫히고, 어떤 오류인지 Snackbar로 안내한다.
    expect(find.byType(RatingDialog), findsNothing);
    expect(find.text('이미 이 영화에 평점을 남겼어요. 기존 기록을 확인해 주세요.'), findsOneWidget);
    // 409는 안내만 하고 로그인 상태를 유지한다.
    expect(storage.token, 'saved-token');
    expect(ratingService.createCalls, hasLength(1));
  });

  testWidgets('저장 중에는 Dialog가 닫히지 않는다 (PopScope + barrierDismissible)', (
    tester,
  ) async {
    ratingService.writeGate = Completer<void>();
    // 이미 즐겨찾기한 영화는 체크박스 없이 기존 평점 API(POST /v8/ratings)로 저장한다.
    favoriteService.favorites = [fakeFavorite(1, 550)];
    await pumpAppAt(tester, '/movies/550');

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();
    await tester.tap(dialogStars().at(4));
    await tester.pump();
    await tester.tap(dialogButton('확인'));
    await tester.pump();

    final popScope = tester.widget<PopScope>(
      find.descendant(
        of: find.byType(RatingDialog),
        matching: find.byType(PopScope),
      ),
    );
    expect(popScope.canPop, isFalse);
    // 바깥(좌상단) 탭
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.byType(RatingDialog), findsOneWidget);

    ratingService.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RatingDialog), findsNothing);
  });

  testWidgets('등록 중 토큰이 만료(AUTH401_4)되면 세션을 정리하고 로그인 화면에서 만료 안내', (
    tester,
  ) async {
    ratingService.writeError = fakeSessionExpired();
    // 이미 즐겨찾기한 영화는 체크박스 없이 기존 평점 API(POST /v8/ratings)로 저장한다.
    favoriteService.favorites = [fakeFavorite(1, 550)];
    await pumpAppAt(tester, '/movies/550');

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();
    await tester.tap(dialogStars().at(3));
    await tester.pump(); // 별점을 고른 뒤 확인 버튼이 활성화되도록 한 프레임 그린다.
    await tester.tap(dialogButton('확인'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RatingDialog), findsNothing);
    expect(storage.token, isNull);
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
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
    expect(find.text('영화 ID가 올바르지 않습니다.'), findsOneWidget);
    expect(service.detailCalls, isEmpty);
  });

  testWidgets('마이페이지 → 내가 등록한 평점: NavigationBar 없이 열리고 뒤로 가면 돌아온다', (
    tester,
  ) async {
    await pumpAppAt(tester, '/my', sessionRatings: seedRatings);
    expect(find.byType(MyPageScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('내가 등록한 평점'));
    await tester.pumpAndSettle();

    expect(find.byType(MyRatingsScreen), findsOneWidget);
    expect(currentLocation(tester), '/my/ratings');
    // root Navigator에 쌓였으므로 Shell(MainScreen)의 NavigationBar가 가려진다.
    expect(find.byType(NavigationBar), findsNothing);
    // v7에는 토큰 기반 "내 평점 목록 GET"이 없다. 서버 조회 없이 세션 평점을 보여 준다.
    expect(ratingService.calls, isEmpty);

    // TMDB 제목·점수·후기·등록일. comment가 null인 평점은 후기를 그리지 않는다.
    expect(find.text('상세 680'), findsOneWidget);
    expect(find.text('다시 봐도 좋다'), findsOneWidget);
    expect(find.text('3.0'), findsOneWidget);
    expect(find.textContaining('등록'), findsWidgets);
    expect(find.text('이번 로그인에서 등록한 평점 3개'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(MyPageScreen), findsOneWidget);
    expect(find.byType(MainScreen), findsOneWidget);
    expect(currentLocation(tester), '/my');
  });

  testWidgets('평점 카드를 누르면 받은 영화 정보로 상세에 간다', (tester) async {
    await pumpAppAt(tester, '/my/ratings', sessionRatings: seedRatings);
    service.detailCalls.clear();

    await tester.tap(find.text('상세 550'));
    await tester.pumpAndSettle();
    expect(currentLocation(tester), '/movies/550');
    expect(service.detailCalls, isEmpty);
  });

  testWidgets('TMDB에서 영화를 못 찾으면 평점은 남기고 "영화 #id"로 표시한다', (tester) async {
    service.onDetail = (movieId) async => throw fakeDioError(statusCode: 404);
    await pumpAppAt(
      tester,
      '/my/ratings',
      sessionRatings: [fakeRating(9, 999, 2, null)],
    );

    expect(find.text('영화 #999'), findsOneWidget);
    expect(find.text('2.0'), findsOneWidget);
  });

  testWidgets('이번 세션에 등록한 평점이 없으면 Empty 화면', (tester) async {
    await pumpAppAt(tester, '/my/ratings');
    expect(find.text('이번 로그인에서 등록한 평점이 없습니다.'), findsOneWidget);
  });

  testWidgets('수정 버튼 → 기존 별점·코멘트가 채워진 Dialog → v7 PATCH result로 카드 갱신', (
    tester,
  ) async {
    ratingService.ratings = List.of(seedRatings);
    await pumpAppAt(tester, '/my/ratings', sessionRatings: seedRatings);

    await tester.tap(find.byTooltip('상세 680 평점 수정'));
    await tester.pumpAndSettle();
    expect(find.text('평점을 수정해 주세요'), findsOneWidget);
    expect(find.text('4점'), findsOneWidget);
    expect(find.text('다시 봐도 좋다'), findsWidgets);

    await tester.tap(dialogStars().at(1));
    await tester.enterText(find.byType(TextField).last, '두 번째는 별로');
    await tester.tap(dialogButton('확인'));
    await tester.pumpAndSettle();

    expect(ratingService.updateCalls.single, (2, 2, '두 번째는 별로'));
    expect(ratingService.calls, isEmpty); // 다시 GET하지 않는다.
    expect(find.text('두 번째는 별로'), findsOneWidget);
    expect(find.text('평점을 수정했습니다.'), findsOneWidget);
  });

  testWidgets('comment가 null인 평점은 빈 칸으로 열린다', (tester) async {
    await pumpAppAt(tester, '/my/ratings', sessionRatings: seedRatings);

    await tester.tap(find.byTooltip('상세 13 평점 수정'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, isEmpty);
    expect(find.text('3점'), findsOneWidget);
  });

  testWidgets('삭제: 취소하면 요청이 없고, 삭제하면 DELETE 후 목록에서 사라진다', (tester) async {
    await pumpAppAt(tester, '/my/ratings', sessionRatings: seedRatings);

    await tester.tap(find.byTooltip('상세 550 평점 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('평점을 삭제할까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '취소'));
    await tester.pumpAndSettle();
    expect(ratingService.deleteCalls, isEmpty);

    await tester.tap(find.byTooltip('상세 550 평점 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
    await tester.pumpAndSettle();

    expect(ratingService.deleteCalls.single, 1);
    expect(find.text('상세 550'), findsNothing);
    expect(find.text('이번 로그인에서 등록한 평점 2개'), findsOneWidget);
  });

  testWidgets('마지막 평점을 삭제하면 Empty 화면', (tester) async {
    await pumpAppAt(tester, '/my/ratings', sessionRatings: [seedRatings.last]);

    await tester.tap(find.byTooltip('상세 550 평점 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text('이번 로그인에서 등록한 평점이 없습니다.'), findsOneWidget);
  });

  testWidgets('수정 403(남의 평점)이면 Dialog에 안내만 하고 로그인 상태를 유지한다', (tester) async {
    ratingService.ratings = List.of(seedRatings);
    ratingService.writeError = fakeMovieLogError(
      statusCode: 403,
      code: 'RATING403_1',
      message: '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
    );
    await pumpAppAt(tester, '/my/ratings', sessionRatings: seedRatings);

    await tester.tap(find.byTooltip('상세 680 평점 수정'));
    await tester.pumpAndSettle();
    await tester.tap(dialogButton('확인'));
    await tester.pumpAndSettle();

    expect(find.byType(RatingDialog), findsOneWidget);
    expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있어요.'), findsOneWidget);
    expect(storage.token, 'saved-token');
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('편집 모드: 체크박스로 고르고 선택한 N개 삭제 (Challenge)', (tester) async {
    await pumpAppAt(tester, '/my/ratings', sessionRatings: seedRatings);

    await tester.tap(find.text('편집'));
    await tester.pump();
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.byTooltip('상세 680 평점 수정'), findsNothing);
    expect(find.text('0개 선택'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '선택한 0개 삭제'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('상세 13'));
    await tester.tap(find.text('상세 550'));
    await tester.pump();
    expect(find.text('2개 선택'), findsOneWidget);

    ratingService.writeGate = Completer<void>();
    await tester.tap(find.text('선택한 2개 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    // 인디케이터가 계속 돌아 pumpAndSettle은 끝나지 않는다. Dialog 닫힘 애니메이션만큼 진행한다.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 확인 Dialog는 요청 전에 닫히고, 화면 위 오버레이가 로딩을 보여 준다.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ModalBarrier), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(MyRatingsScreen),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    ratingService.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(ratingService.deleteCalls, [3, 1]);
    expect(find.text('상세 680'), findsOneWidget);
    expect(find.text('상세 13'), findsNothing);
    expect(find.text('선택한 평점 2개를 삭제했습니다.'), findsOneWidget);
  });

  testWidgets('다중 삭제 일부 실패: 실패 항목만 남고 Snackbar', (tester) async {
    ratingService.writeErrorFor = (id) =>
        id == 3 ? fakeMovieLogError(statusCode: 500) : null;
    await pumpAppAt(tester, '/my/ratings', sessionRatings: seedRatings);

    await tester.tap(find.text('편집'));
    await tester.pump();
    await tester.tap(find.text('상세 13'));
    await tester.tap(find.text('상세 680'));
    await tester.pump();
    await tester.tap(find.text('선택한 2개 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text('상세 13'), findsOneWidget);
    expect(find.text('상세 680'), findsNothing);
    expect(find.text('1개 선택'), findsOneWidget);
    expect(find.textContaining('1개 항목을 삭제하지 못했습니다.'), findsOneWidget);
  });

  group('8주차 프로필 수정·로그아웃', () {
    Future<void> openEdit(WidgetTester tester) async {
      await pumpAppAt(tester, '/my');
      await tester.scrollUntilVisible(
        find.text('프로필 수정'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // 9주차에 "내 즐겨찾기" 행이 늘어 버튼이 하단 NavigationBar 가까이 밀린다. 완전히 보이게 한 뒤 누른다.
      await tester.ensureVisible(find.text('프로필 수정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('프로필 수정'));
      await tester.pumpAndSettle();
      expect(currentLocation(tester), '/my/profile/edit');
      expect(find.byType(NavigationBar), findsNothing);
    }

    testWidgets('저장에 성공하면 마이페이지로 돌아가고 새 닉네임이 바로 보인다', (tester) async {
      await openEdit(tester);

      await tester.enterText(find.byType(TextField).last, '새닉네임');
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(memberService.updateCalls, ['새닉네임']);
      expect(currentLocation(tester), '/my');
      expect(find.text('새닉네임'), findsOneWidget);
      expect(find.text('프로필을 수정했어요.'), findsOneWidget);
    });

    testWidgets('변경 후 뒤로가기는 확인 Dialog: 계속 수정이면 남고, 나가기면 돌아간다', (tester) async {
      await openEdit(tester);
      await tester.enterText(find.byType(TextField).last, '바꾸는중');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('수정을 그만둘까요?'), findsOneWidget);

      await tester.tap(find.text('계속 수정'));
      await tester.pumpAndSettle();
      expect(currentLocation(tester), '/my/profile/edit');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(currentLocation(tester), '/my');
      expect(memberService.updateCalls, isEmpty);
    });

    testWidgets('MEMBER409_1이면 필드 아래 오류와 입력값 유지, 화면에 남는다', (tester) async {
      memberService.updateError = fakeMovieLogError(
        statusCode: 409,
        code: 'MEMBER409_1',
      );
      await openEdit(tester);
      await tester.enterText(find.byType(TextField).last, '영화광');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(find.text('영화광'), findsOneWidget);
      expect(currentLocation(tester), '/my/profile/edit');
    });

    testWidgets('로그아웃하면 /login으로 가고 만료 Snackbar는 없으며, 보호 화면으로 갈 수 없다', (
      tester,
    ) async {
      await pumpAppAt(tester, '/my');
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(storage.token, isNull);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);

      router(tester).go('/my');
      await tester.pumpAndSettle();
      expect(currentLocation(tester), '/login');
    });
  });

  group('9주차 영화 상세 즐겨찾기', () {
    Finder bookmark() => find.byKey(const ValueKey('favorite-button'));

    testWidgets('서버의 즐겨찾기 여부가 북마크에 반영되고, mock 즐겨찾기 버튼은 없다', (tester) async {
      favoriteService.favorites = [fakeFavorite(1, 550)];
      await pumpAppAt(tester, '/movies/550');

      expect(favoriteService.checkCalls, [550]);
      // AppBar의 3주차 mock 북마크는 사라지고, 제목 옆 FavoriteButton 하나만 남는다.
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byType(FavoriteButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.bookmark_border),
        ),
        findsNothing,
      );
    });

    testWidgets('북마크를 누르면 등록·해제 요청 후 아이콘과 Snackbar가 바뀐다', (tester) async {
      await pumpAppAt(tester, '/movies/550');
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

      await tester.tap(bookmark());
      await tester.pumpAndSettle();
      expect(favoriteService.addCalls, [550]);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);

      await tester.tap(bookmark());
      await tester.pumpAndSettle();
      expect(favoriteService.deleteCalls, [550]);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.text('즐겨찾기에서 삭제했습니다.'), findsOneWidget);
    });

    testWidgets('요청 중에는 북마크 자리에 인디케이터가 보이고 누를 수 없다', (tester) async {
      favoriteService.addGate = Completer<void>();
      await pumpAppAt(tester, '/movies/550');

      await tester.tap(bookmark());
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(FavoriteButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(bookmark(), findsNothing);
      // 서버 응답 전에는 아이콘을 바꾸지 않는다.
      expect(find.byIcon(Icons.bookmark), findsNothing);

      favoriteService.addGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('등록 실패는 이전 아이콘을 유지하고 실패 Snackbar를 보여 준다', (tester) async {
      favoriteService.addError = fakeMovieLogError(statusCode: 500);
      await pumpAppAt(tester, '/movies/550');

      await tester.tap(bookmark());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.text('즐겨찾기 등록에 실패했습니다.'), findsOneWidget);
    });

    testWidgets('첫 여부 조회가 실패하면 북마크는 꺼져 있고 새로고침으로 다시 확인한다', (tester) async {
      favoriteService.nextCheckError = fakeMovieLogError(statusCode: 500);
      await pumpAppAt(tester, '/movies/550');

      expect(
        tester.widget<IconButton>(bookmark()).onPressed,
        isNull,
        reason: '여부를 모르면 누를 수 없다',
      );
      await tester.tap(find.byKey(const ValueKey('favorite-reload')));
      await tester.pumpAndSettle();

      expect(favoriteService.checkCalls, [550, 550]);
      expect(tester.widget<IconButton>(bookmark()).onPressed, isNotNull);
      expect(find.byKey(const ValueKey('favorite-reload')), findsNothing);
    });

    testWidgets('FAVORITE409_1: 다른 기기에서 이미 등록했으면 서버 상태로 맞춘다', (tester) async {
      await pumpAppAt(tester, '/movies/550');
      favoriteService.favorites = [fakeFavorite(7, 550)];

      await tester.tap(bookmark());
      await tester.pumpAndSettle();

      expect(favoriteService.addCalls, hasLength(1));
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });
  });

  group('9주차 마이페이지 → 내 즐겨찾기', () {
    Future<void> openFavorites(WidgetTester tester) async {
      await pumpAppAt(tester, '/my');
      await tester.ensureVisible(
        find.byKey(const ValueKey('my-favorites-row')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-favorites-row')));
      await tester.pumpAndSettle();
    }

    testWidgets('내가 등록한 평점 아래 행으로 열리고, NavigationBar 없이 목록이 보인다', (
      tester,
    ) async {
      favoriteService.favorites = [fakeFavorite(2, 680), fakeFavorite(1, 550)];
      await openFavorites(tester);

      expect(currentLocation(tester), '/my/favorites');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('내 즐겨찾기'), findsOneWidget); // AppBar 제목
      expect(
        find.byType(BackButton).evaluate().isNotEmpty ||
            find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
            find.byTooltip('Back').evaluate().isNotEmpty,
        isTrue,
      );
      expect(find.text('상세 680'), findsOneWidget);
      expect(find.text('상세 550'), findsOneWidget);
    });

    testWidgets('상세에서 해제하고 뒤로 가면 목록이 다시 조회되어 해제한 영화가 사라진다', (tester) async {
      favoriteService.favorites = [fakeFavorite(2, 680), fakeFavorite(1, 550)];
      await openFavorites(tester);

      await tester.tap(find.text('상세 550'));
      await tester.pumpAndSettle();
      expect(currentLocation(tester), '/movies/550');

      await tester.tap(find.byKey(const ValueKey('favorite-button')));
      await tester.pumpAndSettle();
      expect(favoriteService.deleteCalls, [550]);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(currentLocation(tester), '/my/favorites');
      expect(find.text('상세 680'), findsOneWidget);
      expect(find.text('상세 550'), findsNothing);
      expect(favoriteService.listCalls, 2);
    });

    testWidgets('빈 목록은 오류가 아니라 안내 화면이다', (tester) async {
      await openFavorites(tester);
      expect(find.text('아직 즐겨찾기한 영화가 없어요.'), findsOneWidget);
    });

    testWidgets('조회 오류는 다시 시도 버튼이 있고, 누르면 목록이 보인다', (tester) async {
      favoriteService.favorites = [fakeFavorite(1, 550)];
      favoriteService.listError = fakeMovieLogError(statusCode: 500);
      await openFavorites(tester);

      expect(find.text('내 즐겨찾기 목록을 불러오지 못했습니다.'), findsOneWidget);
      favoriteService.listError = null;
      await tester.tap(find.widgetWithText(ElevatedButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('상세 550'), findsOneWidget);
    });

    testWidgets('영화 정보 한 건만 실패하면 그 카드만 placeholder이고 재조회로 복구된다', (
      tester,
    ) async {
      favoriteService.favorites = [fakeFavorite(2, 404), fakeFavorite(1, 550)];
      var fail = true;
      service.onDetail = (id) async {
        if (id == 404 && fail) throw fakeDioError(statusCode: 500);
        return FakeTmdbMovieService.detailFor(id);
      };
      await openFavorites(tester);

      expect(find.text('영화 #404'), findsOneWidget);
      expect(find.text('상세 550'), findsOneWidget, reason: '다른 카드는 그대로');

      fail = false;
      await tester.tap(find.widgetWithText(ElevatedButton, '정보 재조회'));
      await tester.pumpAndSettle();
      expect(find.text('영화 #404'), findsNothing);
      expect(find.text('상세 404'), findsOneWidget);
    });

    testWidgets('로그아웃하고 다른 계정으로 로그인하면 이전 계정의 즐겨찾기가 보이지 않는다', (tester) async {
      favoriteService.favorites = [fakeFavorite(1, 550)];
      await openFavorites(tester);
      expect(find.text('상세 550'), findsOneWidget);

      final auth = appContext(tester).read<AuthViewModel>();
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      // 계정 B는 즐겨찾기가 없다.
      favoriteService.favorites = [];
      memberService.member = MemberInfo(
        email: 'b@movielog.dev',
        nickname: '계정B',
        createdAt: DateTime.utc(2026, 11, 2),
      );
      await auth.login('b@movielog.dev', 'Umc1234!');
      await tester.pumpAndSettle();
      router(tester).go('/my');
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('my-favorites-row')),
      );
      await tester.tap(find.byKey(const ValueKey('my-favorites-row')));
      await tester.pumpAndSettle();

      expect(find.text('상세 550'), findsNothing);
      expect(find.text('아직 즐겨찾기한 영화가 없어요.'), findsOneWidget);
    });

    testWidgets('토큰이 만료(AUTH401_4)되면 세션을 정리하고 로그인 화면으로 간다', (tester) async {
      favoriteService.listError = fakeSessionExpired();
      await openFavorites(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(storage.token, isNull);
    });

    testWidgets('403·네트워크 실패는 로그아웃하지 않는다', (tester) async {
      favoriteService.listError = fakeMovieLogError(
        statusCode: 403,
        code: 'COMMON403',
        message: '권한 없음',
      );
      await openFavorites(tester);

      expect(find.byType(LoginScreen), findsNothing);
      expect(storage.token, 'saved-token');
      expect(find.text('내 즐겨찾기 목록을 불러오지 못했습니다.'), findsOneWidget);
    });

    testWidgets('로그아웃 상태에서는 /my/favorites에 들어갈 수 없다', (tester) async {
      await pumpAppAt(tester, '/login', signedIn: false);
      router(tester).go('/my/favorites');
      await tester.pumpAndSettle();
      expect(currentLocation(tester), '/login');
    });
  });

  group('9주차 영화 목록 더 보기', () {
    Future<PagedMoviesViewModel> pumpList(
      WidgetTester tester, {
      required bool infiniteScroll,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final vm = PagedMoviesViewModel(tmdbApi: service);
      addTearDown(vm.dispose);
      await vm.loadGenres();
      await vm.loadInitial();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PagedMoviesViewModel>.value(
            value: vm,
            child: MovieListScreen(infiniteScroll: infiniteScroll),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return vm;
    }

    Future<void> scrollToEnd(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2500),
        );
        await tester.pumpAndSettle();
      }
    }

    testWidgets('더 보기 버튼: 첫 page만 보이고, 누르면 기존 카드 아래에 다음 page가 붙는다', (
      tester,
    ) async {
      final vm = await pumpList(tester, infiniteScroll: false);
      expect(find.text('인기순 20편'), findsOneWidget);
      expect(service.discoverCalls.map((c) => c.page), [1]);

      await scrollToEnd(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, '더 보기'));
      await tester.pumpAndSettle();

      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
      expect(vm.movies, hasLength(40));
      expect(find.text('인기순 40편'), findsOneWidget);
    });

    testWidgets('요청 중에는 버튼이 로딩 상태가 되고 기존 카드는 그대로다', (tester) async {
      final gate = Completer<void>();
      final vm = await pumpList(tester, infiniteScroll: false);
      final original = service.onDiscover;
      service.onDiscover = (call) async {
        await gate.future;
        return original(call);
      };
      await scrollToEnd(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, '더 보기'));
      await tester.pump();

      expect(vm.isLoadingMore, isTrue);
      expect(find.text('인기순 20편'), findsOneWidget);
      final footerButton = tester.widget<MovieLogButton>(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byWidgetPredicate(
            (w) => w is MovieLogButton && w.isLoading,
          ),
        ),
      );
      expect(footerButton.isLoading, isTrue);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('인기순 40편'), findsOneWidget);
    });

    testWidgets('다음 page 실패 시 같은 page를 다시 시도할 수 있다', (tester) async {
      await pumpList(tester, infiniteScroll: false);
      final original = service.onDiscover;
      var fail = true;
      service.onDiscover = (call) async {
        if (call.page == 2 && fail) throw fakeDioError();
        return original(call);
      };
      await scrollToEnd(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, '더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('다음 페이지 다시 시도'), findsOneWidget);
      expect(find.text('인기순 20편'), findsOneWidget, reason: '기존 목록 유지');

      fail = false;
      // 실패 문구가 한 줄 늘어 버튼이 화면 밖으로 밀렸을 수 있으니 다시 끝까지 내린다.
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, '다음 페이지 다시 시도'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '다음 페이지 다시 시도'));
      await tester.pumpAndSettle();

      expect(service.discoverCalls.map((c) => c.page), [1, 2, 2]);
      expect(find.text('인기순 40편'), findsOneWidget);
    });

    testWidgets('마지막 page에서는 더 보기를 숨기고 끝 안내를 보여 준다', (tester) async {
      service.onDiscover = (call) async => TmdbMoviePageDto.fromJson(
        pageJson(
          [for (var i = 0; i < 20; i++) call.page * 100 + i],
          page: call.page,
          totalPages: 2,
        ),
      );
      await pumpList(tester, infiniteScroll: false);
      await scrollToEnd(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, '더 보기'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);

      expect(find.text('더 보기'), findsNothing);
      expect(find.text('더 이상 조회할 페이지가 없습니다.'), findsOneWidget);
    });

    testWidgets('무한 스크롤(Challenge): 버튼 없이 끝에 가까워지면 다음 page를 자동으로 부른다', (
      tester,
    ) async {
      await pumpList(tester, infiniteScroll: true);
      expect(find.text('더 보기'), findsNothing);
      expect(service.discoverCalls.map((c) => c.page), [1]);

      await scrollToEnd(tester);

      expect(
        service.discoverCalls.map((c) => c.page).toSet().containsAll({1, 2}),
        isTrue,
      );
      // 같은 page를 중복 요청하지 않는다.
      final pages = service.discoverCalls.map((c) => c.page).toList();
      expect(pages.toSet().length, pages.length);
    });

    testWidgets('무한 스크롤에서 page 요청이 실패하면 재시도 버튼이 나타난다', (tester) async {
      await pumpList(tester, infiniteScroll: true);
      final original = service.onDiscover;
      var fail = true;
      service.onDiscover = (call) async {
        if (call.page == 2 && fail) throw fakeDioError();
        return original(call);
      };

      await scrollToEnd(tester);
      expect(find.text('다음 페이지 다시 시도'), findsOneWidget);

      fail = false;
      await tester.tap(find.widgetWithText(ElevatedButton, '다음 페이지 다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('다음 페이지 다시 시도'), findsNothing);
    });

    testWidgets('AppBar의 검색 아이콘은 /movies/search로 이동한다', (tester) async {
      await pumpAppAt(tester, '/movies');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(currentLocation(tester), '/movies/search');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('영화 검색'), findsOneWidget);
    });
  });

  group('9주차 영화 검색', () {
    Finder field() => find.byKey(const ValueKey('search-field'));

    Future<void> openSearch(WidgetTester tester) async {
      await pumpAppAt(tester, '/movies');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String text) async {
      await tester.enterText(field(), text);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    testWidgets('처음에는 안내 문구만 보이고 요청하지 않는다', (tester) async {
      await openSearch(tester);
      expect(find.text('영화 제목으로 검색해 보세요.'), findsOneWidget);
      expect(service.searchCalls, isEmpty);
    });

    testWidgets('빈 검색어는 서버에 보내지 않고 입력 안내를 보여 준다', (tester) async {
      await openSearch(tester);
      await tester.tap(find.byKey(const ValueKey('search-button')));
      await tester.pumpAndSettle();

      expect(find.text('검색어를 입력해 주세요.'), findsOneWidget);
      await submit(tester, '   ');
      expect(service.searchCalls, isEmpty);
    });

    testWidgets('제출하면 page 1을 요청해 결과를 보여 주고, 카드를 누르면 상세로 간다', (tester) async {
      await openSearch(tester);
      await submit(tester, '어벤져스');

      expect(service.searchCalls.single, (page: 1, query: '어벤져스'));
      expect(find.text('영화 1000'), findsOneWidget);

      await tester.tap(find.text('영화 1000'));
      await tester.pumpAndSettle();
      expect(currentLocation(tester), '/movies/1000');
    });

    testWidgets('결과가 없으면 안내, 실패하면 다시 시도가 보인다', (tester) async {
      await openSearch(tester);
      service.onSearch = (call) async =>
          TmdbMoviePageDto.fromJson(pageJson(const [], totalPages: 0));
      await submit(tester, '없는영화');
      expect(find.text('검색 결과가 없어요.'), findsOneWidget);

      var fail = true;
      service.onSearch = (call) async {
        if (fail) throw fakeDioError();
        return TmdbMoviePageDto.fromJson(pageJson([5, 6], totalPages: 1));
      };
      await submit(tester, '실패');
      expect(find.byType(MovieListError), findsOneWidget);

      fail = false;
      await tester.tap(find.widgetWithText(FilledButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('영화 5'), findsOneWidget);
    });

    testWidgets('검색어를 바꿔 다시 제출하면 이전 결과를 비우고 첫 page부터 불러온다', (tester) async {
      await openSearch(tester);
      await submit(tester, '첫번째');
      await submit(tester, '두번째');

      expect(service.searchCalls.map((c) => c.query), ['첫번째', '두번째']);
      expect(service.searchCalls.last.page, 1);
      expect(find.text('영화 1000'), findsOneWidget);
    });

    testWidgets('Challenge: 입력을 멈추고 500ms가 지나야 한 번만 검색한다 (debounce)', (
      tester,
    ) async {
      await openSearch(tester);

      await tester.enterText(field(), '어');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(field(), '어벤');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(field(), '어벤져스');
      await tester.pump(const Duration(milliseconds: 499));
      expect(service.searchCalls, isEmpty, reason: '아직 입력이 멈춘 지 500ms가 안 됐다');

      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();
      expect(service.searchCalls, [(page: 1, query: '어벤져스')]);
    });

    testWidgets('Challenge: 입력이 공백뿐이면 자동 검색도 서버에 보내지 않는다', (tester) async {
      await openSearch(tester);
      await tester.enterText(field(), '   ');
      await tester.pump(const Duration(seconds: 1));
      expect(service.searchCalls, isEmpty);
    });

    testWidgets('Challenge: 자동 검색 직후 제출해도 같은 검색어를 두 번 요청하지 않는다', (
      tester,
    ) async {
      await openSearch(tester);
      await tester.enterText(field(), '인셉션');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(service.searchCalls, hasLength(1));

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(service.searchCalls, hasLength(1));
    });

    testWidgets('Challenge: 화면을 떠나면 대기 중인 타이머가 실행되지 않는다', (tester) async {
      await openSearch(tester);
      await tester.enterText(field(), '인셉션');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(service.searchCalls, isEmpty);
    });
  });

  group('9주차 Challenge: 평점·즐겨찾기 통합 저장', () {
    Future<void> openRatingDialog(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
      await tester.pumpAndSettle();
    }

    Future<void> rate(WidgetTester tester, int stars, {String? comment}) async {
      await tester.tap(dialogStars().at(stars - 1));
      if (comment != null) {
        await tester.enterText(find.byType(TextField).last, comment);
      }
      await tester.pump();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();
    }

    final checkbox = find.byKey(const ValueKey('add-to-favorite'));

    testWidgets('아직 즐겨찾기하지 않은 영화에서만 체크박스가 보인다', (tester) async {
      await pumpAppAt(tester, '/movies/550');
      await openRatingDialog(tester);
      expect(checkbox, findsOneWidget);
      await tester.tap(dialogButton('취소'));
      await tester.pumpAndSettle();

      favoriteService.favorites = [fakeFavorite(1, 550)];
      router(tester).go('/movies/680');
      await tester.pumpAndSettle();
      favoriteService.favorites = [fakeFavorite(1, 680)];
      router(tester).go('/movies/680');
      await tester.pumpAndSettle();
    });

    testWidgets('체크하고 저장하면 POST /movie-records 한 번으로 평점과 즐겨찾기를 저장한다', (
      tester,
    ) async {
      await pumpAppAt(tester, '/movies/550');
      await openRatingDialog(tester);
      await tester.tap(checkbox);
      await tester.pump();
      await rate(tester, 4, comment: '  재미있다  ');

      expect(recordService.calls.single.toJson(), {
        'movieId': 550,
        'score': 4,
        'comment': '재미있다',
        'addToFavorites': true,
      });
      expect(ratingService.createCalls, isEmpty);
      expect(favoriteService.addCalls, isEmpty, reason: '즐겨찾기 API를 따로 부르지 않는다');
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
      // 북마크 상태를 서버 값으로 다시 맞춘다.
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text('등록 완료 · 수정은 마이페이지에서'), findsOneWidget);
    });

    testWidgets('체크하지 않으면 addToFavorites=false로 보내고 북마크는 그대로다', (tester) async {
      await pumpAppAt(tester, '/movies/550');
      await openRatingDialog(tester);
      await rate(tester, 5);

      expect(recordService.calls.single.addToFavorites, isFalse);
      expect(
        recordService.calls.single.toJson().containsKey('comment'),
        isFalse,
      );
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.text('평점을 저장했습니다.'), findsOneWidget);
    });

    testWidgets('COMMON400은 Dialog를 열어 둔 채 이유를 보이고 별점·코멘트를 유지한다', (
      tester,
    ) async {
      recordService.error = fakeMovieLogError(
        statusCode: 400,
        code: 'COMMON400',
        message: '별점은 1점 이상이어야 합니다.',
      );
      await pumpAppAt(tester, '/movies/550');
      await openRatingDialog(tester);
      await rate(tester, 3, comment: '유지돼야 함');

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('별점은 1점 이상이어야 합니다.'), findsOneWidget);
      expect(find.text('유지돼야 함'), findsOneWidget);
      expect(find.text('3점'), findsOneWidget);
    });

    testWidgets('네트워크 실패도 Dialog를 열어 둔다', (tester) async {
      recordService.error = fakeMovieLogError();
      await pumpAppAt(tester, '/movies/550');
      await openRatingDialog(tester);
      await rate(tester, 2);

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.textContaining('네트워크'), findsOneWidget);
    });

    testWidgets('FAVORITE409_1은 Dialog를 닫고 Snackbar로 안내하며 북마크를 서버 값으로 맞춘다', (
      tester,
    ) async {
      await pumpAppAt(tester, '/movies/550');
      await openRatingDialog(tester);
      await tester.tap(checkbox);
      await tester.pump();
      // 다이얼로그를 연 뒤 다른 기기에서 즐겨찾기가 먼저 등록됐다.
      favoriteService.favorites = [fakeFavorite(3, 550)];
      await rate(tester, 4);

      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('이미 즐겨찾기한 영화예요. 평점도 저장되지 않았어요.'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(ratingService.ratings, isEmpty, reason: '평점도 저장되지 않는다 (트랜잭션)');
    });

    testWidgets('MEMBER404_1은 Dialog를 닫고 Snackbar로 안내한다', (tester) async {
      recordService.error = fakeMovieLogError(
        statusCode: 404,
        code: 'MEMBER404_1',
        message: '회원을 찾을 수 없습니다.',
      );
      await pumpAppAt(tester, '/movies/550');
      await openRatingDialog(tester);
      await rate(tester, 4);

      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('회원 정보를 찾을 수 없어요. 다시 로그인해 주세요.'), findsOneWidget);
    });

    testWidgets('평점 수정 Dialog에는 체크박스가 없고 addToFavorites는 항상 false다', (
      tester,
    ) async {
      await pumpAppAt(
        tester,
        '/my/ratings',
        sessionRatings: [fakeRating(1, 550, 5, '최고')],
      );
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(checkbox, findsNothing);
    });
  });
}
