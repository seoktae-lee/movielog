// 영화 목록 ViewModel: 최대 30개 수집, 장르 재조회, 늦은 응답 무시, 새로고침을 확인한다.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

import 'support/fake_tmdb_movie_service.dart';
import 'support/tmdb_fixtures.dart';

void main() {
  group('최대 30개 만들기', () {
    test('한 페이지 20개면 2페이지까지만 요청하고 정확히 30개를 만든다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);

      final movies = await viewModel.fetchUpToThirtyMovies();

      expect(movies, hasLength(30));
      expect(service.discoverCalls.map((call) => call.page), [1, 2]);
      // 1페이지 20개 + 2페이지 앞 10개
      expect(movies.first.id, 1000);
      expect(movies.last.id, 2009);
    });

    test('페이지 사이에 같은 영화가 오면 TMDB id 기준으로 하나만 남긴다', () async {
      final service = FakeTmdbMovieService(
        onDiscover: (call) async =>
            TmdbMoviePageDto.fromJson(switch (call.page) {
              // 2페이지 앞 5개(15~19)는 1페이지와 겹친다.
              1 => pageJson(idRange(0, 20)),
              2 => pageJson(idRange(15, 20), page: 2),
              _ => pageJson(idRange(100, 20), page: call.page),
            }),
      );
      final viewModel = MovieListViewModel(service);

      final movies = await viewModel.fetchUpToThirtyMovies();
      final ids = movies.map((movie) => movie.id).toList();

      expect(ids, hasLength(30));
      expect(ids.toSet(), hasLength(30));
      expect(ids, idRange(0, 30));
    });

    test('마지막 페이지에 닿으면 30개보다 적어도 멈추고 오류로 보지 않는다', () async {
      final service = FakeTmdbMovieService(
        onDiscover: (call) async => TmdbMoviePageDto.fromJson(
          pageJson(idRange(call.page * 100, 8), page: call.page, totalPages: 2),
        ),
      );
      final viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(service.discoverCalls, hasLength(2));
      expect(viewModel.movies, hasLength(16));
      expect(viewModel.status, MovieListLoadStatus.success);
    });

    test('빈 페이지가 오면 더 요청하지 않고 Empty가 된다', () async {
      final service = FakeTmdbMovieService(
        onDiscover: (call) async =>
            TmdbMoviePageDto.fromJson(pageJson(const [], totalPages: 500)),
      );
      final viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(service.discoverCalls, hasLength(1));
      expect(viewModel.status, MovieListLoadStatus.empty);
    });
  });

  group('장르 선택', () {
    test('처음에는 장르 목록과 전체 영화를 함께 불러온다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();

      expect(service.genreCalls, 1);
      expect(viewModel.genres.map((genre) => genre.id), [28, 12, 16, 18]);
      expect(viewModel.genreNames[28], '액션');
      expect(service.discoverCalls.first.genreIds, isEmpty);
      expect(viewModel.status, MovieListLoadStatus.success);
    });

    test('장르를 고르면 로컬에서 거르지 않고 page 1부터 with_genres로 다시 요청한다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      service.discoverCalls.clear();

      await viewModel.selectGenre(28);

      expect(viewModel.selectedGenreIds, [28]);
      expect(service.discoverCalls.first.page, 1);
      expect(service.discoverCalls.first.genreIds, [28]);
      expect(viewModel.movies, hasLength(30));
    });

    test('같은 장르를 다시 누르거나 전체를 누르면 장르 조건 없이 요청한다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      await viewModel.selectGenre(28);
      await viewModel.selectGenre(28);
      expect(viewModel.selectedGenreIds, isEmpty);
      expect(service.discoverCalls.last.genreIds, isEmpty);

      await viewModel.selectGenre(12);
      await viewModel.selectGenre(null);
      expect(viewModel.selectedGenreIds, isEmpty);
    });

    test('장르가 바뀌면 이전 목록을 비우고 Loading부터 시작한다', () async {
      final gate = Completer<void>();
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      service.onDiscover = (call) async {
        await gate.future;
        return TmdbMoviePageDto.fromJson(
          pageJson(idRange(1, 20), totalPages: 1),
        );
      };
      final pending = viewModel.selectGenres(const [28, 12]);

      expect(viewModel.status, MovieListLoadStatus.loading);
      expect(viewModel.movies, isEmpty);
      expect(viewModel.isBusy, isTrue);

      gate.complete();
      await pending;
      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.selectedGenreIds, [28, 12]);
    });

    test('요청 중에는 장르를 바꿀 수 없다', () async {
      final gate = Completer<void>();
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      service.onDiscover = (call) async {
        await gate.future;
        return TmdbMoviePageDto.fromJson(
          pageJson(idRange(1, 20), totalPages: 1),
        );
      };
      final first = viewModel.selectGenre(28);
      await viewModel.selectGenre(12); // 무시되어야 한다.

      expect(viewModel.selectedGenreIds, [28]);
      gate.complete();
      await first;
      expect(service.discoverCalls.last.genreIds, [28]);
    });

    test('늦게 도착한 이전 요청의 응답은 버린다 (request version)', () async {
      final slow = Completer<TmdbMoviePageDto>();
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();

      // 1) 액션 요청은 오래 걸린다. 2) 그 사이 Error 화면의 재시도로 드라마 조건 요청이 먼저 끝난다.
      service.onDiscover = (call) => slow.future;
      final oldRequest = viewModel.selectGenre(28);

      service.onDiscover = (call) async =>
          TmdbMoviePageDto.fromJson(pageJson(const [7, 8, 9], totalPages: 1));
      viewModel.selectedGenreIds = const [18];
      await viewModel.retry();
      expect(viewModel.movies.map((movie) => movie.id), [7, 8, 9]);

      slow.complete(
        TmdbMoviePageDto.fromJson(pageJson(const [1, 2], totalPages: 1)),
      );
      await oldRequest;

      // 옛 응답(1, 2)이 새 결과를 덮어쓰지 않는다.
      expect(viewModel.movies.map((movie) => movie.id), [7, 8, 9]);
    });
  });

  group('실패와 재시도', () {
    test('처음 요청이 실패하면 Error가 되고, 재시도하면 page 1부터 다시 요청한다', () async {
      var fail = true;
      final service = FakeTmdbMovieService(
        onDiscover: (call) async {
          if (fail) throw fakeDioError();
          return TmdbMoviePageDto.fromJson(
            pageJson(idRange(1, 20), totalPages: 1),
          );
        },
      );
      final viewModel = MovieListViewModel(service);

      await viewModel.loadInitial();
      expect(viewModel.status, MovieListLoadStatus.error);
      expect(viewModel.message, contains('네트워크'));

      fail = false;
      service.discoverCalls.clear();
      await viewModel.retry();

      expect(viewModel.status, MovieListLoadStatus.success);
      expect(service.discoverCalls.first.page, 1);
    });

    test('새로고침이 성공하면 같은 장르로 page 1부터 다시 받아 목록을 바꾼다', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      await viewModel.selectGenre(16);
      service.discoverCalls.clear();

      service.onDiscover = (call) async =>
          TmdbMoviePageDto.fromJson(pageJson(const [42], totalPages: 1));
      final succeeded = await viewModel.refresh();

      expect(succeeded, isTrue);
      expect(service.discoverCalls.single.page, 1);
      expect(service.discoverCalls.single.genreIds, [16]);
      expect(viewModel.movies.map((movie) => movie.id), [42]);
    });

    test('새로고침 중에는 기존 목록을 유지하고, 실패해도 지우지 않는다', () async {
      final gate = Completer<void>();
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.loadInitial();
      final before = viewModel.movies;

      service.onDiscover = (call) async {
        await gate.future;
        throw fakeDioError();
      };
      final pending = viewModel.refresh();

      expect(viewModel.isRefreshing, isTrue);
      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.movies, same(before));

      gate.complete();
      final succeeded = await pending;

      expect(succeeded, isFalse);
      expect(viewModel.isRefreshing, isFalse);
      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.movies, same(before));
    });
  });

  test('dispose 뒤에 응답이 와도 notifyListeners 오류가 나지 않는다', () async {
    final gate = Completer<void>();
    final service = FakeTmdbMovieService(
      onDiscover: (call) async {
        await gate.future;
        return TmdbMoviePageDto.fromJson(pageJson(idRange(1, 20)));
      },
    );
    final viewModel = MovieListViewModel(service);
    final pending = viewModel.loadInitial();

    viewModel.dispose();
    gate.complete();

    await expectLater(pending, completes);
  });
}
