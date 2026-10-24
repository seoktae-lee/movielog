// 내 평점 ViewModel: 자체 API 평점 + TMDB 영화 정보를 합치는지 확인한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/services/movielog_member_service.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';

import 'support/fake_movielog_member_service.dart';
import 'support/fake_tmdb_movie_service.dart';

void main() {
  test('평점마다 movieId로 TMDB 상세를 불러 붙인다', () async {
    final tmdb = FakeTmdbMovieService();
    final viewModel = MyRatingsViewModel(
      FakeMovieLogMemberService(),
      tmdb,
      memberId: 1,
    );

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(tmdb.detailCalls, [155, 550]);
    expect(viewModel.items.map((item) => item.movie?.title), [
      '상세 155',
      '상세 550',
    ]);
  });

  test('TMDB 한 편이 실패해도 평점은 그대로 보여 준다', () async {
    final tmdb = FakeTmdbMovieService(
      onDetail: (movieId) async => movieId == 550
          ? throw fakeDioError(statusCode: 404)
          : FakeTmdbMovieService().fetchMovieDetail(movieId),
    );
    final viewModel = MyRatingsViewModel(
      FakeMovieLogMemberService(),
      tmdb,
      memberId: 1,
    );

    await viewModel.load();

    expect(viewModel.items, hasLength(2));
    expect(viewModel.items.last.movie, isNull);
    expect(viewModel.items.last.rating.movieId, 550);
  });

  test('평점이 없으면 Empty, 서버 오류면 Error', () async {
    final empty = MyRatingsViewModel(
      FakeMovieLogMemberService(ratings: []),
      FakeTmdbMovieService(),
      memberId: 2,
    );
    await empty.load();
    expect(empty.status, MyRatingsLoadStatus.empty);

    final error = MyRatingsViewModel(
      FakeMovieLogMemberService(
        error: const MovieLogApiException('존재하지 않는 유저입니다.', statusCode: 404),
      ),
      FakeTmdbMovieService(),
      memberId: 999,
    );
    await error.load();
    expect(error.status, MyRatingsLoadStatus.error);
    expect(error.message, '존재하지 않는 유저입니다.');
  });
}
