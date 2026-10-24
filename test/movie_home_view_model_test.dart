// 홈 ViewModel: Popular 결과에서 안전하게 최대 5개만 쓰는지 확인한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';

import 'support/fake_tmdb_movie_service.dart';
import 'support/tmdb_fixtures.dart';

void main() {
  test('Popular 20개 중 앞의 5개만 순서대로 보관한다', () async {
    final service = FakeTmdbMovieService();
    final viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.status, MovieHomeLoadStatus.success);
    expect(viewModel.popularMovies.map((movie) => movie.id), idRange(100, 5));
    expect(service.popularCalls, 1);
  });

  test('결과가 5개보다 적어도 RangeError 없이 있는 만큼만 보관한다', () async {
    final service = FakeTmdbMovieService(
      onPopular: (_) async => TmdbMoviePageDto.fromJson(pageJson([1, 2, 3])),
    );
    final viewModel = MovieHomeViewModel(service);

    await viewModel.loadPopular();

    expect(viewModel.popularMovies, hasLength(3));
    expect(viewModel.status, MovieHomeLoadStatus.success);
  });

  test('빈 결과는 Empty, 요청 실패는 Error 상태가 된다', () async {
    final emptyViewModel = MovieHomeViewModel(
      FakeTmdbMovieService(
        onPopular: (_) async => TmdbMoviePageDto.fromJson(pageJson(const [])),
      ),
    );
    await emptyViewModel.loadPopular();
    expect(emptyViewModel.status, MovieHomeLoadStatus.empty);

    final errorViewModel = MovieHomeViewModel(
      FakeTmdbMovieService(
        onPopular: (_) async => throw fakeDioError(statusCode: 401),
      ),
    );
    await errorViewModel.loadPopular();
    expect(errorViewModel.status, MovieHomeLoadStatus.error);
    expect(errorViewModel.message, contains('인증'));
  });

  test('Loading을 먼저 알린 뒤 결과 상태를 알린다', () async {
    final viewModel = MovieHomeViewModel(FakeTmdbMovieService());
    final seen = <MovieHomeLoadStatus>[];
    viewModel.addListener(() => seen.add(viewModel.status));

    await viewModel.loadPopular();

    expect(seen, [MovieHomeLoadStatus.loading, MovieHomeLoadStatus.success]);
  });
}
