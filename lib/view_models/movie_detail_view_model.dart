import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import 'submit_status.dart';

export 'submit_status.dart';

/// 영화 상세 화면 전용 ViewModel. 현재 영화 DTO와 **평점 등록** 상태를 관리한다.
///
/// TMDB 조회는 [MovieDetailLoader]가 끝낸 뒤 이 ViewModel을 만든다.
/// 상세 화면은 등록만 하고, 조회·수정·삭제는 마이페이지의 "내가 등록한 평점"(MyRatingsViewModel)이 맡는다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this.memberId, this.movie);

  final RatingApiService _ratingService;

  /// 학습용 현재 회원(LearningMemberSession). 로그인 인증은 아니다. 가입 전이면 null.
  final int? memberId;

  /// 평점 요청의 movieId는 목록 index가 아니라 이 DTO의 TMDB id다.
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  /// 이번 화면에서 등록에 성공한 점수. "내 평점" 영역에 보여 준다. (서버 목록은 마이페이지에서 다시 조회)
  int? registeredScore;

  bool _disposed = false;

  bool get canRegister => memberId != null;

  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    if (id == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = '먼저 회원가입을 완료해 주세요.';
      notifyListeners();
      return;
    }
    if (submitStatus == SubmitStatus.submitting) return;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      await _ratingService.createRating(
        memberId: id,
        request: CreateRatingRequest(
          movieId: movie.id,
          score: score,
          comment: comment,
        ),
      );
      // 화면을 떠난 뒤 도착한 결과는 반영하지 않는다.
      if (_disposed) return;
      submitStatus = SubmitStatus.success;
      registeredScore = score;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      // 400(별점 범위)·404(없는 유저)·409(이미 등록) — 서버 message를 그대로 쓴다.
      submitMessage = writeErrorMessage(error);
    } on StateError catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = error.message;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
