// 영화 목록·검색이 함께 쓰는 PagedMoviesViewModel (9주차):
// 한 page씩 조회, 중복 제거, 실패 시 같은 page 재시도, 조건 변경 시 초기화, 늦은 응답 무시.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

import 'support/fake_tmdb_movie_service.dart';
import 'support/tmdb_fixtures.dart';

TmdbMoviePageDto page(List<int> ids, {int p = 1, int total = 3}) =>
    TmdbMoviePageDto.fromJson(pageJson(ids, page: p, totalPages: total));

void main() {
  late FakeTmdbMovieService tmdb;
  late PagedMoviesViewModel vm;

  setUp(() {
    tmdb = FakeTmdbMovieService();
    vm = PagedMoviesViewModel(tmdbApi: tmdb);
  });

  tearDown(() => vm.dispose());

  test('첫 page만 불러온다 (30개를 모으지 않는다)', () async {
    await vm.loadInitial();

    expect(vm.phase, LoadPhase.ready);
    expect(vm.movies, hasLength(20));
    expect(tmdb.discoverCalls.map((c) => c.page), [1]);
    expect(vm.nextPage, 2);
    expect(vm.hasMore, isTrue);
  });

  test('로딩 중에는 loading, 영화가 없으면 empty (오류가 아니다)', () async {
    tmdb.onDiscover = (call) async => page(const [], total: 0);
    final seen = <LoadPhase>[];
    vm.addListener(() => seen.add(vm.phase));

    await vm.loadInitial();

    expect(seen.first, LoadPhase.loading);
    expect(vm.phase, LoadPhase.empty);
  });

  test('첫 조회 실패는 error이고 다시 시도하면 ready', () async {
    var fail = true;
    tmdb.onDiscover = (call) async {
      if (fail) throw fakeDioError();
      return page([1, 2, 3], total: 1);
    };

    await vm.loadInitial();
    expect(vm.phase, LoadPhase.error);
    expect(vm.errorMessage, isNotNull);

    fail = false;
    await vm.retry();
    expect(vm.phase, LoadPhase.ready);
    expect(vm.movies.map((m) => m.id), [1, 2, 3]);
  });

  test('다음 page는 기존 카드를 유지한 채 붙고, 이미 가진 movieId는 뺀다', () async {
    tmdb.onDiscover = (call) async => switch (call.page) {
      1 => page([1, 2, 3], p: 1),
      _ => page([3, 4, 5], p: 2), // 3은 page 1에도 있었다
    };
    await vm.loadInitial();

    final loadingSeen = <bool>[];
    final during = <int>[];
    vm.addListener(() {
      loadingSeen.add(vm.isLoadingMore);
      during.add(vm.movies.length);
    });
    await vm.loadNextPage();

    expect(loadingSeen.first, isTrue);
    expect(during.first, 3, reason: '추가 로딩 중에도 기존 목록을 지우지 않는다');
    expect(vm.movies.map((m) => m.id), [1, 2, 3, 4, 5]);
    expect(vm.nextPage, 3);
    expect(vm.isLoadingMore, isFalse);
  });

  test('다음 page 요청이 실패하면 목록·nextPage를 유지하고 같은 page를 다시 요청한다', () async {
    var fail = true;
    tmdb.onDiscover = (call) async {
      if (call.page == 2 && fail) throw fakeDioError();
      return page([call.page * 10 + 1, call.page * 10 + 2], p: call.page);
    };
    await vm.loadInitial();

    await vm.loadNextPage();
    expect(vm.loadMoreError, isNotNull);
    expect(vm.movies, hasLength(2));
    expect(vm.nextPage, 2, reason: '실패하면 page 번호를 올리지 않는다');
    expect(vm.phase, LoadPhase.ready, reason: '첫 로딩 실패(error)와 구분된다');

    fail = false;
    await vm.loadNextPage();
    expect(vm.loadMoreError, isNull);
    expect(vm.movies.map((m) => m.id), [11, 12, 21, 22]);
    // page 2를 두 번 요청했고 page 3은 건너뛰지 않았다.
    expect(tmdb.discoverCalls.map((c) => c.page), [1, 2, 2]);
  });

  test('요청 중 더 보기를 또 눌러도 같은 page를 한 번만 요청한다', () async {
    await vm.loadInitial();
    final gate = Completer<void>();
    tmdb.onDiscover = (call) async {
      await gate.future;
      return page([100, 101], p: call.page);
    };

    final first = vm.loadNextPage();
    final second = vm.loadNextPage();
    gate.complete();
    await Future.wait([first, second]);

    expect(tmdb.discoverCalls.where((c) => c.page == 2), hasLength(1));
  });

  test('마지막 page에서는 hasMore가 false가 되어 더 요청하지 않는다', () async {
    tmdb.onDiscover = (call) async => page([call.page], p: call.page, total: 2);
    await vm.loadInitial();
    await vm.loadNextPage();

    expect(vm.hasMore, isFalse);
    await vm.loadNextPage();
    expect(tmdb.discoverCalls.map((c) => c.page), [1, 2]);
  });

  test('total_pages가 500보다 커도 501은 요청하지 않는다', () async {
    tmdb.onDiscover = (call) async =>
        page([call.page], p: call.page, total: 38000);
    await vm.loadInitial();
    expect(vm.totalPages, 500);

    vm.nextPage = 500; // 500페이지까지 왔다고 가정한다.
    await vm.loadNextPage();
    expect(vm.nextPage, 501);
    expect(vm.hasMore, isFalse);
    await vm.loadNextPage();
    expect(tmdb.discoverCalls.map((c) => c.page), [1, 500]);
  });

  test('장르가 바뀌면 목록·page·추가 로딩 상태를 모두 비우고 첫 page부터 다시 요청한다', () async {
    var failNext = true;
    tmdb.onDiscover = (call) async {
      if (call.page == 2 && failNext) throw fakeDioError();
      return page([call.page * 10], p: call.page);
    };
    await vm.loadInitial();
    await vm.loadNextPage(); // 실패 → loadMoreError가 남는다
    expect(vm.loadMoreError, isNotNull);

    failNext = false;
    await vm.selectGenres([28, 18]);

    expect(vm.loadMoreError, isNull);
    expect(vm.isLoadingMore, isFalse);
    expect(vm.movies.map((m) => m.id), [10]);
    expect(vm.nextPage, 2);
    expect(tmdb.discoverCalls.last.page, 1);
    expect(tmdb.discoverCalls.last.genreIds, [28, 18]);
  });

  test('이전 장르의 느린 응답은 새 목록에 섞이지 않는다 (generation)', () async {
    final slow = Completer<TmdbMoviePageDto>();
    tmdb.onDiscover = (call) {
      if (call.genreIds?.contains(28) ?? false) return slow.future;
      return Future.value(page([7, 8], total: 1));
    };

    final first = vm.loadInitial(genreIds: [28]);
    await Future<void>.delayed(Duration.zero);
    // 아직 첫 응답이 오지 않은 상태에서 조건을 바꾼다.
    await vm.loadInitial(genreIds: [18]);
    expect(vm.movies.map((m) => m.id), [7, 8]);

    slow.complete(page([1, 2, 3], total: 1)); // 늦게 도착
    await first;

    expect(vm.movies.map((m) => m.id), [7, 8]);
    expect(vm.selectedGenreIds, [18]);
  });

  test('검색어는 trim하고 Search API로 요청하며, 바꿔 다시 검색하면 첫 page부터', () async {
    await vm.loadInitial(query: '  어벤져스  ');
    expect(tmdb.searchCalls.single, (page: 1, query: '어벤져스'));
    expect(tmdb.discoverCalls, isEmpty);

    await vm.loadNextPage();
    expect(tmdb.searchCalls.last, (page: 2, query: '어벤져스'));

    await vm.loadInitial(query: '인셉션');
    expect(tmdb.searchCalls.last, (page: 1, query: '인셉션'));
    expect(
      vm.movies.every((m) => m.id < 2000),
      isTrue,
      reason: '이전 검색 결과를 비웠다',
    );
  });

  test('검색 결과가 없으면 empty, 실패하면 검색 전용 문구의 error', () async {
    tmdb.onSearch = (call) async => page(const [], total: 0);
    await vm.loadInitial(query: '없는영화');
    expect(vm.phase, LoadPhase.empty);

    tmdb.onSearch = (call) async => throw fakeDioError();
    await vm.loadInitial(query: '실패');
    expect(vm.phase, LoadPhase.error);
    expect(vm.errorMessage, contains('네트워크'));
  });

  test('응답의 page가 요청과 다르면 오류로 본다', () async {
    tmdb.onDiscover = (call) async => page([1], p: 5);
    await vm.loadInitial();
    expect(vm.phase, LoadPhase.error);
  });

  test('당겨서 새로고침: 기존 목록을 유지하다 성공하면 교체하고, 실패하면 false', () async {
    await vm.loadInitial();
    final before = vm.movies.map((m) => m.id).toList();

    tmdb.onDiscover = (call) async => throw fakeDioError();
    expect(await vm.refresh(), isFalse);
    expect(vm.movies.map((m) => m.id), before, reason: '실패해도 목록을 지우지 않는다');
    expect(vm.isRefreshing, isFalse);

    tmdb.onDiscover = (call) async => page([9, 8], total: 1);
    expect(await vm.refresh(), isTrue);
    expect(vm.movies.map((m) => m.id), [9, 8]);
  });

  test('dispose된 뒤에 응답이 도착해도 알림을 보내지 않는다 (SafeNotify)', () async {
    final gate = Completer<TmdbMoviePageDto>();
    tmdb.onDiscover = (call) => gate.future;
    final local = PagedMoviesViewModel(tmdbApi: tmdb);

    final future = local.loadInitial();
    local.dispose();
    gate.complete(page([1], total: 1));

    await expectLater(future, completes);
  });

  test('장르 Chip: 이미 그 장르만 선택돼 있으면 해제한다', () async {
    await vm.selectGenre(28);
    expect(vm.selectedGenreIds, [28]);
    await vm.selectGenre(28);
    expect(vm.selectedGenreIds, isEmpty);
    await vm.selectGenre(18);
    await vm.selectGenre(null);
    expect(vm.selectedGenreIds, isEmpty);
  });
}
