import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'tmdb_error_message.dart';

enum MovieHomeLoadStatus { idle, loading, success, empty, error }

/// 홈 화면 전용 ViewModel.
///
/// Popular 결과 중 앞 5개만 "지금 인기 있는 영화"로 보관한다.
/// "5개"는 화면 정책이므로 Service가 아니라 여기서 정한다.
class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  final TmdbMovieService _service;

  static const popularCount = 5;

  List<TmdbMovieDto> popularMovies = const [];
  MovieHomeLoadStatus status = MovieHomeLoadStatus.idle;
  String? message;

  bool _disposed = false;

  Future<void> loadPopular() async {
    status = MovieHomeLoadStatus.loading;
    message = null;
    notifyListeners(); // Loading으로 바뀌었음을 구독 중인 Widget에 알린다.

    try {
      final page = await _service.fetchPopular();
      // [0]~[4]를 직접 꺼내면 5개보다 적을 때 RangeError가 난다.
      // take(5)는 있는 만큼만 돌려준다.
      popularMovies = page.results.take(popularCount).toList();
      status = popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
    } catch (error) {
      status = MovieHomeLoadStatus.error;
      message = tmdbErrorMessage(error, fallback: '인기 영화를 불러오지 못했어요.');
    }

    // 요청 중에 탭을 옮겨 화면이 사라졌다면 알릴 대상이 없다.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
