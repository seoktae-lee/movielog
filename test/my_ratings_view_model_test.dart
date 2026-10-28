// 내가 등록한 평점 ViewModel: 4가지 상태·TMDB 연결 규칙(6주차)과 수정·삭제·다중 삭제(7주차)를 확인한다.

import 'dart:async';

import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';

import 'support/fake_movielog_services.dart';
import 'support/fake_tmdb_movie_service.dart';

void main() {
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

  group('수정·삭제 (7주차)', () {
    late FakeRatingApiService service;
    late MyRatingsViewModel viewModel;

    setUp(() async {
      service = FakeRatingApiService();
      viewModel = MyRatingsViewModel(service, FakeTmdbMovieService(), 42);
      await viewModel.load();
      service.calls.clear();
    });

    test('수정 성공 → 그 뒤 GET으로 목록을 다시 읽는다', () async {
      await viewModel.updateRating(ratingId: 2, score: 1, comment: null);

      expect(service.updateCalls.single, (42, 2, 1, null));
      expect(service.calls, [42]);
      final updated = viewModel.ratings.firstWhere(
        (e) => e.rating.ratingId == 2,
      );
      expect(updated.rating.score, 1);
      expect(updated.rating.comment, isNull);
    });

    test('400 쓰기 실패는 rethrow하고 다시 조회하지 않는다', () async {
      service.writeError = fakeMovieLogError(
        statusCode: 400,
        code: 'COMMON400',
        message: '별점은 5점 이하여야 합니다.',
      );

      await expectLater(
        viewModel.updateRating(ratingId: 2, score: 5),
        throwsA(isA<DioException>()),
      );
      expect(service.calls, isEmpty);
    });

    test('403·404 쓰기 실패는 rethrow하면서 목록을 다시 맞춘다', () async {
      service.writeError = fakeMovieLogError(
        statusCode: 404,
        code: 'COMMON404',
        message: '존재하지 않는 평점입니다.',
      );

      await expectLater(
        viewModel.deleteRating(2),
        throwsA(isA<DioException>()),
      );
      expect(service.calls, [42]);
    });

    test('저장은 성공했는데 GET만 실패하면 rethrow하지 않고 refreshWarning만 남긴다', () async {
      service.error = fakeMovieLogError(); // 이후 GET 실패

      await viewModel.updateRating(ratingId: 2, score: 3, comment: '수정');

      expect(service.updateCalls, hasLength(1));
      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.refreshWarning, contains('저장은 완료됐지만'));

      // 조회만 다시 시도: 쓰기 요청은 더 가지 않는다.
      service.error = null;
      await viewModel.load();
      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.refreshWarning, isNull);
      expect(service.updateCalls, hasLength(1));
    });

    test('마지막 평점을 지우면 Empty', () async {
      for (final id in [3, 2, 1]) {
        await viewModel.deleteRating(id);
      }
      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });

    test('다중 삭제: 일부 실패면 실패한 항목만 선택에 남고 안내 문구', () async {
      viewModel.enterEditMode();
      viewModel
        ..toggleSelected(3)
        ..toggleSelected(2)
        ..toggleSelected(1);
      service.writeErrorFor = (id) => id == 2
          ? fakeMovieLogError(statusCode: 404, code: 'COMMON404')
          : null;

      final loading = <bool>[];
      viewModel.addListener(() => loading.add(viewModel.isDeletingSelected));
      await viewModel.deleteSelectedRatings();

      expect(loading.first, isTrue);
      expect(viewModel.isDeletingSelected, isFalse);
      expect(service.deleteCalls.map((c) => c.$2), [3, 2, 1]);
      expect(viewModel.selectedRatingIds, {2});
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2]);
      expect(viewModel.isEditMode, isTrue);
      expect(
        viewModel.takeSnackbarMessage(),
        '1개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.',
      );
    });

    test('다중 삭제가 모두 성공하면 편집 모드가 끝난다', () async {
      viewModel
        ..enterEditMode()
        ..toggleSelected(3)
        ..toggleSelected(1);
      await viewModel.deleteSelectedRatings();

      expect(viewModel.isEditMode, isFalse);
      expect(viewModel.selectedRatingIds, isEmpty);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2]);
      expect(viewModel.takeSnackbarMessage(), isNull);
    });

    test('취소하면 선택이 모두 풀린다', () {
      viewModel
        ..enterEditMode()
        ..toggleSelected(3)
        ..exitEditMode();
      expect(viewModel.isEditMode, isFalse);
      expect(viewModel.selectedRatingIds, isEmpty);
    });
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
