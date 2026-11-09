import 'package:flutter/foundation.dart';

import '../data/models/rating_dto.dart';
import 'auth_view_model.dart';

/// 이번 로그인 세션에서 등록한 평점(v7 등록 result의 Rating 객체) 보관함.
///
/// v7 로그인·내 정보 응답에는 memberId가 없고, 토큰 기반 "내 평점 목록 GET"도 없다.
/// 그래서 "내가 등록한 평점" 화면은 서버 목록이 아니라 **이 세션에서 받은 Rating**을 보여 준다.
/// 앱을 재시작하면 비어 있다. (재시작 뒤 전체 복원은 계약 확인 전까지 완료 기능으로 보지 않는다)
///
/// 로그아웃·만료·다른 계정 로그인으로 [AuthViewModel.sessionVersion]이 바뀌면 자동으로 비운다.
/// 이전 세션 요청의 늦은 응답은 버전이 달라 [add]·[replace]·[remove]에서 무시된다.
class SessionRatingStore extends ChangeNotifier {
  SessionRatingStore(this._auth) : _boundVersion = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  int _boundVersion;
  final List<RatingDto> _ratings = [];

  /// 최근에 등록한 것이 위로 온다. (서버 목록과 같은 ratingId 내림차순)
  List<RatingDto> get ratings => List.unmodifiable(_ratings);

  RatingDto? findByMovie(int movieId) {
    for (final rating in _ratings) {
      if (rating.movieId == movieId) return rating;
    }
    return null;
  }

  void _onAuthChanged() {
    if (_auth.sessionVersion == _boundVersion) return;
    _boundVersion = _auth.sessionVersion;
    if (_ratings.isEmpty) return;
    _ratings.clear();
    notifyListeners();
  }

  bool _accepts(int version) =>
      version == _boundVersion && version == _auth.sessionVersion;

  /// 등록 성공 result를 추가한다. [version]은 요청을 보낼 때의 세션 버전.
  void add(int version, RatingDto rating) {
    if (!_accepts(version)) return;
    _ratings
      ..removeWhere((r) => r.ratingId == rating.ratingId)
      ..insert(0, rating);
    notifyListeners();
  }

  /// 수정 성공 result로 같은 ratingId 항목을 바꾼다.
  void replace(int version, RatingDto rating) {
    if (!_accepts(version)) return;
    final index = _ratings.indexWhere((r) => r.ratingId == rating.ratingId);
    if (index < 0) return;
    _ratings[index] = rating;
    notifyListeners();
  }

  /// 삭제 성공(또는 RATING404_1로 이미 없음)이면 뺀다.
  void remove(int version, int ratingId) {
    if (!_accepts(version)) return;
    final before = _ratings.length;
    _ratings.removeWhere((r) => r.ratingId == ratingId);
    if (_ratings.length != before) notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
