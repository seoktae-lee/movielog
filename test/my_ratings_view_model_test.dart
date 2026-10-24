// 내가 등록한 평점 ViewModel: 4가지 상태와 TMDB 연결 규칙을 확인한다.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';

import 'support/fake_movielog_services.dart';
import 'support/fake_tmdb_movie_service.dart';

void main() {
  test('조회 대상은 학습용 memberId 1이다', () {
    expect(sampleMemberId, 1);
  });

  test('loading → success, 평점마다 TMDB 영화를 붙인다', () async {
    final ratingService = FakeRatingApiService();
    final tmdb = FakeTmdbMovieService();
    final viewModel = MyRatingsViewModel(ratingService, tmdb, 1);
    final seen = <MyRatingsLoadStatus>[];
    viewModel.addListener(() => seen.add(viewModel.status));

    await viewModel.load();

    expect(seen, [MyRatingsLoadStatus.loading, MyRatingsLoadStatus.success]);
    expect(ratingService.calls, [1]);
    expect(viewModel.ratings.map((entry) => entry.movie?.title), [
      '상세 13',
      '상세 680',
      '상세 550',
    ]);
    expect(viewModel.message, isNull);
  });

  test('빈 배열은 Error가 아니라 Empty', () async {
    final viewModel = MyRatingsViewModel(
      FakeRatingApiService(ratings: []),
      FakeTmdbMovieService(),
      3,
    );
    await viewModel.load();
    expect(viewModel.status, MyRatingsLoadStatus.empty);
  });

  test('404·400은 Error와 각자의 문구', () async {
    final service = FakeRatingApiService()
      ..error = fakeMovieLogError(statusCode: 404);
    final viewModel = MyRatingsViewModel(service, FakeTmdbMovieService(), 4);

    await viewModel.load();
    expect(viewModel.status, MyRatingsLoadStatus.error);
    expect(viewModel.message, '존재하지 않는 회원입니다.');

    service.error = fakeMovieLogError(statusCode: 400);
    await viewModel.load();
    expect(viewModel.message, 'memberId 형식을 다시 확인해 주세요.');
  });

  test('TMDB에 없는 영화(404)는 null로 두고 평점은 남긴다', () async {
    final tmdb = FakeTmdbMovieService(
      onDetail: (movieId) async => movieId == 680
          ? throw fakeDioError(statusCode: 404)
          : TmdbMovieDto.fromJson({'id': movieId, 'title': '상세 $movieId'}),
    );
    final viewModel = MyRatingsViewModel(FakeRatingApiService(), tmdb, 1);

    await viewModel.load();

    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings, hasLength(3));
    expect(viewModel.ratings[1].movie, isNull);
    expect(viewModel.ratings[1].rating.comment, '다시 봐도 좋다');
    expect(viewModel.message, contains('일부 영화 정보'));
  });

  test('같은 movieId는 한 번만 조회하고, 404는 캐시해 다시 묻지 않는다', () async {
    final rating550 = FakeRatingApiService.defaultRatings.last;
    final tmdb = FakeTmdbMovieService(
      onDetail: (movieId) async => movieId == 13
          ? throw fakeDioError(statusCode: 404)
          : TmdbMovieDto.fromJson({'id': movieId, 'title': '상세 $movieId'}),
    );
    final viewModel = MyRatingsViewModel(
      FakeRatingApiService(
        ratings: [rating550, rating550, FakeRatingApiService.defaultRatings[0]],
      ),
      tmdb,
      1,
    );

    await viewModel.load();
    await viewModel.load();

    expect(tmdb.detailCalls, [550, 13]);
  });

  test('일시적 네트워크 실패는 캐시하지 않고 다음 로딩에서 다시 시도한다', () async {
    var failing = true;
    final tmdb = FakeTmdbMovieService(
      onDetail: (movieId) async => failing
          ? throw fakeDioError()
          : TmdbMovieDto.fromJson({'id': movieId, 'title': '상세 $movieId'}),
    );
    final viewModel = MyRatingsViewModel(
      FakeRatingApiService(ratings: [FakeRatingApiService.defaultRatings[2]]),
      tmdb,
      1,
    );

    await viewModel.load();
    expect(viewModel.ratings.single.movie, isNull);

    failing = false;
    await viewModel.load();
    expect(viewModel.ratings.single.movie?.title, '상세 550');
    expect(tmdb.detailCalls, [550, 550]);
  });

  test('먼저 시작한 요청이 늦게 끝나면 그 결과는 버린다', () async {
    final first = Completer<List<RatingDto>>();
    final service = _ControlledRatingApiService([
      first.future,
      Future.value(<RatingDto>[]),
    ]);
    final viewModel = MyRatingsViewModel(service, FakeTmdbMovieService(), 1);

    final firstLoad = viewModel.load();
    await viewModel.load(); // 두 번째 요청: 빈 배열 → empty
    first.complete(FakeRatingApiService.defaultRatings);
    await firstLoad;

    expect(viewModel.status, MyRatingsLoadStatus.empty);
  });
}

/// 호출 순서대로 미리 정한 Future를 돌려준다.
class _ControlledRatingApiService extends FakeRatingApiService {
  _ControlledRatingApiService(this._responses);

  final List<Future<List<RatingDto>>> _responses;
  var _index = 0;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) => _responses[_index++];
}
