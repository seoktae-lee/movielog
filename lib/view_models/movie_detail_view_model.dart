import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'session_rating_store.dart';
import 'submit_status.dart';

export 'submit_status.dart';

/// 영화 상세 화면 전용 ViewModel. 현재 영화 DTO와 **평점 등록** 상태를 관리한다.
///
/// 8주차: `POST /v7/ratings`로 등록한다. path·body에 memberId가 없고, 보호용 Client가 토큰을 붙인다.
/// 등록 result(Rating 객체)를 [SessionRatingStore]에 넣어 "내가 등록한 평점"에서 수정·삭제한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._auth,
    this._store,
    this.movie,
  ) {
    _store.addListener(_notify);
  }

  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatingStore _store;

  /// 평점 요청의 movieId는 목록 index가 아니라 이 DTO의 TMDB id다.
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  bool _disposed = false;

  /// 이번 세션에서 이 영화에 등록한 평점. 마이페이지에서 수정·삭제하면 여기도 바뀐다.
  RatingDto? get myRating => _store.findByMovie(movie.id);

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return;
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    _notify();

    try {
      final created = await _ratingService.createRating(
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      );
      // 화면을 떠났거나 그사이 로그아웃·계정 전환이 있었으면 반영하지 않는다.
      if (_disposed || version != _auth.sessionVersion) return;
      _store.add(version, created);
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed || version != _auth.sessionVersion) return;
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
      // 401만 세션을 정리한다. 409(이미 등록)·400은 안내만 하고 로그인 상태를 유지한다.
      if (isSessionExpiredError(error)) await _auth.expireSession(version);
    } on StateError catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = error.message;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_notify);
    super.dispose();
  }
}
