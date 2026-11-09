// 내가 등록한 평점 ViewModel (8주차): 세션 평점 보관함 + v7 수정·삭제·다중 삭제를 확인한다.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/session_rating_store.dart';

import 'support/fake_movielog_services.dart';
import 'support/fake_tmdb_movie_service.dart';

void main() {
  late FakeRatingApiService ratingService;
  late FakeTmdbMovieService tmdb;
  late InMemoryTokenStorage storage;
  late AuthViewModel auth;
  late SessionRatingStore store;

  final seed = <RatingDto>[
    fakeRating(3, 13, 3, null),
    fakeRating(2, 680, 4, '다시 봐도 좋다'),
    fakeRating(1, 550, 5, '최고의 영화!'),
  ];

  /// 토큰이 있는 상태로 세션 복원 → signedIn. 그다음 [ratings]를 이번 세션 평점으로 넣는다.
  Future<MyRatingsViewModel> createSignedIn([List<RatingDto>? ratings]) async {
    ratingService = FakeRatingApiService(ratings: ratings ?? seed);
    tmdb = FakeTmdbMovieService();
    storage = InMemoryTokenStorage('saved-token');
    auth = AuthViewModel(
      FakeAuthApiService(),
      FakeMemberApiService(),
      storage,
    );
    await auth.restoreSession();
    expect(auth.status, AuthStatus.signedIn);
    store = SessionRatingStore(auth);
    for (final rating in (ratings ?? seed).reversed) {
      store.add(auth.sessionVersion, rating);
    }
    return MyRatingsViewModel(ratingService, tmdb, auth, store);
  }

  test('loading → success, 평점마다 TMDB 영화를 붙이고 서버 GET은 하지 않는다', () async {
    final viewModel = await createSignedIn();
    final seen = <MyRatingsLoadStatus>[];
    viewModel.addListener(() => seen.add(viewModel.status));

    await viewModel.load();

    expect(seen.first, MyRatingsLoadStatus.loading);
    expect(viewModel.status, MyRatingsLoadStatus.success);
    expect(viewModel.ratings.map((e) => e.movie?.id), [13, 680, 550]);
    expect(ratingService.calls, isEmpty);
  });

  test('세션 평점이 없으면 Empty', () async {
    final viewModel = await createSignedIn(const []);
    await viewModel.load();
    expect(viewModel.status, MyRatingsLoadStatus.empty);
  });

  test('TMDB에 없는 영화는 movie null로 두고 평점은 남긴다', () async {
    final viewModel = await createSignedIn([fakeRating(9, 999, 2, null)]);
    tmdb.onDetail = (id) async => throw fakeDioError(statusCode: 404);
    await viewModel.load();

    expect(viewModel.ratings.single.movie, isNull);
    expect(viewModel.message, contains('영화 #id'));
  });

  test('수정 성공 result로 그 카드만 바뀐다 (PATCH 전체 교체, GET 없음)', () async {
    final viewModel = await createSignedIn();
    await viewModel.load();

    await viewModel.updateRating(ratingId: 2, score: 1, comment: null);
    await pumpEventQueue();

    expect(ratingService.updateCalls.single, (2, 1, null));
    final card = viewModel.ratings.firstWhere((e) => e.rating.ratingId == 2);
    expect(card.rating.score, 1);
    expect(card.rating.comment, isNull);
    expect(ratingService.calls, isEmpty);
  });

  test('403은 rethrow만 하고 로그인 상태·목록을 유지한다', () async {
    final viewModel = await createSignedIn();
    await viewModel.load();
    ratingService.writeError = fakeMovieLogError(
      statusCode: 403,
      code: 'RATING403_1',
    );

    await expectLater(
      viewModel.updateRating(ratingId: 2, score: 1),
      throwsA(anything),
    );
    expect(auth.status, AuthStatus.signedIn);
    expect(storage.token, 'saved-token');
    expect(viewModel.ratings, hasLength(3));
  });

  test('404(RATING404_1)는 이미 없는 평점이므로 목록에서 뺀다', () async {
    final viewModel = await createSignedIn();
    await viewModel.load();
    ratingService.writeError = fakeMovieLogError(
      statusCode: 404,
      code: 'RATING404_1',
    );

    await expectLater(viewModel.deleteRating(1), throwsA(anything));
    await pumpEventQueue();
    expect(viewModel.ratings.map((e) => e.rating.ratingId), [3, 2]);
  });

  test('401(AUTH401_4)이면 세션을 정리하고 보관함도 비운다', () async {
    final viewModel = await createSignedIn();
    await viewModel.load();
    ratingService.writeError = fakeSessionExpired();

    await expectLater(viewModel.deleteRating(1), throwsA(anything));
    await pumpEventQueue();

    expect(auth.status, AuthStatus.signedOut);
    expect(auth.sessionExpired, isTrue);
    expect(storage.token, isNull);
    expect(store.ratings, isEmpty);
  });

  test('로그아웃 뒤 늦게 도착한 수정 응답은 반영하지 않는다', () async {
    final viewModel = await createSignedIn();
    await viewModel.load();
    ratingService.writeGate = Completer<void>();

    final pending = viewModel.updateRating(ratingId: 2, score: 1);
    await auth.logout();
    ratingService.writeGate!.complete();
    await pending;

    expect(store.ratings, isEmpty); // 새 세션에 이전 세션 평점이 섞이지 않는다.
  });

  group('다중 삭제 (Challenge)', () {
    test('일부 실패면 실패한 항목만 선택에 남고 안내 문구', () async {
      final viewModel = await createSignedIn();
      await viewModel.load();
      ratingService.writeErrorFor = (id) =>
          id == 3 ? fakeMovieLogError(statusCode: 500) : null;

      viewModel.enterEditMode();
      viewModel.toggleSelected(3);
      viewModel.toggleSelected(2);
      await viewModel.deleteSelectedRatings();
      await pumpEventQueue();

      expect(ratingService.deleteCalls, [3, 2]);
      expect(viewModel.selectedRatingIds, {3});
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [3, 1]);
      expect(viewModel.takeSnackbarMessage(), contains('1개 항목'));
      expect(viewModel.isEditMode, isTrue);
    });

    test('모두 성공하면 편집 모드가 끝난다', () async {
      final viewModel = await createSignedIn();
      await viewModel.load();

      viewModel.enterEditMode();
      viewModel.toggleSelected(1);
      await viewModel.deleteSelectedRatings();
      await pumpEventQueue();

      expect(viewModel.isEditMode, isFalse);
      expect(viewModel.ratings, hasLength(2));
    });

    test('도중에 세션이 만료되면 남은 요청을 보내지 않는다', () async {
      final viewModel = await createSignedIn();
      await viewModel.load();
      ratingService.writeError = fakeSessionExpired();

      viewModel.enterEditMode();
      viewModel.toggleSelected(3);
      viewModel.toggleSelected(2);
      await viewModel.deleteSelectedRatings();

      expect(ratingService.deleteCalls, [3]);
      expect(auth.status, AuthStatus.signedOut);
    });

    test('취소하면 선택이 모두 풀린다', () async {
      final viewModel = await createSignedIn();
      viewModel.enterEditMode();
      viewModel.toggleSelected(1);
      viewModel.exitEditMode();
      expect(viewModel.selectedRatingIds, isEmpty);
      expect(viewModel.isEditMode, isFalse);
    });
  });
}
