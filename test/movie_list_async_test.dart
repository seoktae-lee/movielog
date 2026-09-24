// 4주차 영화 목록의 Loading·Empty·Error·Success 상태와 재시도·장르 저장을 확인하는 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/services/genre_preference.dart';
import 'package:movielog/services/movie_service.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/movie_card.dart';
import 'package:movielog/widgets/movie_grid.dart';
import 'package:movielog/widgets/movie_list_empty.dart';
import 'package:movielog/widgets/movie_list_error.dart';
import 'package:movielog/widgets/movie_list_loading.dart';

void main() {
  // 기기 저장소 대신 메모리 저장소를 쓴다. 테스트마다 새로 비운다.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  MovieService fake(MovieLoadMode mode) =>
      FakeMovieService(mode: mode, delay: const Duration(milliseconds: 100));

  late GoRouter router;

  Future<void> pumpMovieList(
    WidgetTester tester, {
    required MovieService service,
    String initialLocation = '/movies',
  }) async {
    // 세로가 긴 폰 크기로 고정해 Grid가 화면 안에 들어오게 한다.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/movies',
          builder: (context, state) {
            final raw = state.uri.queryParameters['genre'];
            return MovieListScreen(
              selectedGenres: raw == null || raw.isEmpty
                  ? const <String>{}
                  : raw.split(',').toSet(),
              movieService: service,
            );
          },
        ),
        GoRoute(
          path: '/movies/:movieId',
          builder: (context, state) => const Scaffold(body: Text('상세 화면')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  testWidgets('처음에는 Loading을 보여 주고, 완료되면 Success Grid로 바뀐다', (
    WidgetTester tester,
  ) async {
    await pumpMovieList(tester, service: fake(MovieLoadMode.success));

    // 아직 Future가 완료되지 않았다: ConnectionState.waiting
    expect(find.byType(MovieListLoading), findsOneWidget);
    expect(find.byType(MovieGrid), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(MovieListLoading), findsNothing);
    expect(find.byType(MovieGrid), findsOneWidget);
    expect(find.byType(MovieCard), findsNWidgets(6));
  });

  testWidgets('빈 목록으로 완료되면 Empty 화면을 보여 준다', (WidgetTester tester) async {
    await pumpMovieList(tester, service: fake(MovieLoadMode.empty));
    await tester.pumpAndSettle();

    expect(find.byType(MovieListEmpty), findsOneWidget);
    expect(find.text('아직 등록된 영화가 없습니다.'), findsOneWidget);
    // 빈 목록은 오류가 아니므로 Error 화면이 나오면 안 된다.
    expect(find.byType(MovieListError), findsNothing);
  });

  testWidgets('오류로 완료되면 Error 화면과 다시 시도 버튼을 보여 준다', (
    WidgetTester tester,
  ) async {
    await pumpMovieList(tester, service: fake(MovieLoadMode.failure));
    await tester.pumpAndSettle();

    expect(find.byType(MovieListError), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsOneWidget);
    // 내부 예외 이름이나 StackTrace를 화면에 그대로 노출하지 않는다.
    expect(find.textContaining('MovieLoadException'), findsNothing);
    expect(find.textContaining('#0'), findsNothing);
  });

  testWidgets('다시 시도를 누르면 새 Future로 다시 불러온다', (WidgetTester tester) async {
    // 첫 시도만 실패하는 Service로 "실패 → 재시도 → 성공"을 재현한다.
    await pumpMovieList(tester, service: fake(MovieLoadMode.failFirst));
    await tester.pumpAndSettle();
    expect(find.byType(MovieListError), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '다시 시도'));
    await tester.pump();

    // 새 Future가 만들어졌으므로 Loading부터 다시 시작한다.
    expect(find.byType(MovieListLoading), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(MovieGrid), findsOneWidget);
    expect(find.byType(MovieCard), findsNWidgets(6));
  });

  testWidgets('장르 Chip을 누르면 선택 장르가 저장되고, 영화를 다시 부르지는 않는다', (
    WidgetTester tester,
  ) async {
    final service = FakeMovieService(delay: const Duration(milliseconds: 100));
    await pumpMovieList(tester, service: service);
    await tester.pumpAndSettle();
    expect(service.attempt, 1);

    await tester.tap(find.widgetWithText(ChoiceChip, 'SF'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/movies?genre=SF');
    expect(find.byType(MovieCard), findsOneWidget);
    expect(await GenrePreference().read(), {'SF'});
    // URL만 바뀌고 State는 그대로라 Future를 새로 만들지 않는다(= Loading이 다시 뜨지 않는다).
    expect(service.attempt, 1);
    expect(find.byType(MovieListLoading), findsNothing);
  });

  testWidgets('저장된 장르가 있으면 앱을 다시 켰을 때 그 장르로 복원된다', (WidgetTester tester) async {
    // 앱을 껐다 켠 상황: 저장소에는 지난번 선택이 남아 있다.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          GenrePreference.selectedGenresKey: <String>['SF'],
        });

    await pumpMovieList(tester, service: fake(MovieLoadMode.success));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/movies?genre=SF');
    expect(find.byType(MovieCard), findsOneWidget);
    expect(find.text('우주의 끝에서'), findsOneWidget);
  });

  testWidgets('선택한 장르에 영화가 없으면 Empty 화면과 필터 해제 버튼을 보여 준다', (
    WidgetTester tester,
  ) async {
    await pumpMovieList(
      tester,
      service: fake(MovieLoadMode.success),
      initialLocation: '/movies?genre=없는장르',
    );
    await tester.pumpAndSettle();

    expect(find.byType(MovieListEmpty), findsOneWidget);
    expect(find.text('선택한 장르의 영화가 없습니다.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '전체 영화 보기'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/movies');
    expect(find.byType(MovieCard), findsNWidgets(6));
  });
}
