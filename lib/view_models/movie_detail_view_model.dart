import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'tmdb_error_message.dart';

enum MovieDetailLoadStatus { idle, loading, success, notFound, error }

/// 영화 상세 화면 전용 ViewModel.
///
/// 목록·홈에서 넘어오면 이미 받은 DTO([initialMovie])를 그대로 쓰고,
/// URL로 바로 들어와 DTO가 없으면 [movieId]로 TMDB 상세 API를 호출한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._service, {
    required this.movieId,
    TmdbMovieDto? initialMovie,
  }) : movie = initialMovie;

  final TmdbMovieService _service;

  /// Path Parameter(`/movies/:movieId`)로 받은 TMDB id. 숫자가 아니면 null.
  final int? movieId;

  TmdbMovieDto? movie;
  MovieDetailLoadStatus status = MovieDetailLoadStatus.idle;
  String? message;

  bool _disposed = false;

  Future<void> load() async {
    final id = movieId;
    if (id == null) {
      status = MovieDetailLoadStatus.notFound;
      notifyListeners();
      return;
    }

    // 넘겨받은 DTO의 id가 URL의 id와 같을 때만 믿고 쓴다.
    if (movie?.id == id) {
      status = MovieDetailLoadStatus.success;
      notifyListeners();
      return;
    }

    status = MovieDetailLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      movie = await _service.fetchMovieDetail(id);
      status = MovieDetailLoadStatus.success;
    } on DioException catch (error) {
      status = error.response?.statusCode == 404
          ? MovieDetailLoadStatus.notFound
          : MovieDetailLoadStatus.error;
      message = tmdbErrorMessage(error, fallback: '영화 정보를 불러오지 못했어요.');
    } catch (error) {
      status = MovieDetailLoadStatus.error;
      message = '영화 정보를 불러오지 못했어요.';
    }

    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
