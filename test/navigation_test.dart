// 화면 흐름을 실제 AppRouter + Provider로 검증하는 Widget 테스트.
//
// 네트워크 대신 Fake Service를 MovieLogApp에 넣는다.
// 8주차: 저장소에 토큰이 있으면 세션 복원(GET me) → /home으로 시작한다.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/app/movie_log_app.dart';
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
import 'package:movielog/view_models/session_rating_store.dart';
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
  late FakeAuthApiService authService;
  late FakeMemberApiService memberService;
  late InMemoryTokenStorage storage;

  setUp(() {
    service = FakeTmdbMovieService();
    checkService = FakeSignUpService();
    ratingService = FakeRatingApiService();
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

  Finder dialogStars() => find.descendant(
    of: find.byType(RatingDialog),
    matching: find.byIcon(Icons.star),
  );
  Finder dialogButton(String label) => find.descendant(
    of: find.byType(RatingDialog),
    matching: find.widgetWithText(ElevatedButton, label),
  );

  testWidgets('상세에서 평점 등록: TMDB id·정수 score·comment로 POST하고 성공 Snackbar', (
    tester,
  ) async {
    await pumpAppAt(tester, '/movies/550');

    await tester.tap(find.widgetWithText(ElevatedButton, '평점 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingDialog), findsOneWidget);
    // 별점을 고르기 전에는 코멘트를 써도 확인을 누를 수 없다.
    await tester.enterText(find.byType(TextField).last, '  다시 보고 싶다  ');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(dialogButton('확인')).onPressed, isNull);

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
    expect(find.textContaining('평점을 등록했습니다.'), findsOneWidget);
    // 등록 result(Rating 객체)로 "내 평점"이 바로 바뀌고 같은 영화에 다시 POST할 수 없다.
    expect(find.text('등록 완료 · 수정은 마이페이지에서'), findsOneWidget);
  });

  testWidgets('등록 409면 Dialog가 열린 채 서버 문구를 보여 주고 입력을 유지한다', (tester) async {
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

    expect(find.byType(RatingDialog), findsOneWidget);
    expect(find.text('이미 이 영화에 평점을 남겼어요. 기존 기록을 확인해 주세요.'), findsOneWidget);
    // 409는 안내만 하고 로그인 상태를 유지한다.
    expect(storage.token, 'saved-token');
    expect(find.text('코멘트'), findsOneWidget);
    expect(find.text('4점'), findsOneWidget);
    // 실패 뒤에도 로딩이 풀려 다시 시도할 수 있다.
    expect(
      tester.widget<ElevatedButton>(dialogButton('확인')).onPressed,
      isNotNull,
    );

    await tester.tap(dialogButton('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingDialog), findsNothing);
    expect(ratingService.createCalls, hasLength(1));
  });

  testWidgets('저장 중에는 Dialog가 닫히지 않는다 (PopScope + barrierDismissible)', (
    tester,
  ) async {
    ratingService.writeGate = Completer<void>();
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
}
