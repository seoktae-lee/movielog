import 'package:flutter/foundation.dart';

import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'tmdb_error_message.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

/// 영화 목록 화면 전용 ViewModel.
///
/// - 장르 목록(Genre API)과 Discover 결과 최대 30개를 보관한다.
/// - 장르가 바뀌면 이미 받은 30개를 로컬에서 거르지 않고, `with_genres`로 page 1부터 다시 요청한다.
/// - 요청이 겹치면 [_requestVersion]으로 늦게 도착한 옛 응답을 버린다.
class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service);

  final TmdbMovieService _service;

  static const maxMovies = 30;

  List<TmdbMovieDto> movies = const [];
  List<TmdbGenreDto> genres = const [];

  /// 선택된 장르 ID 목록. 비어 있으면 "전체"이고 `with_genres`를 보내지 않는다.
  List<int> selectedGenreIds = const [];

  MovieListLoadStatus status = MovieListLoadStatus.idle;
  String? message;

  /// 당겨서 새로고침 중인지. 이때는 목록을 지우지 않고 그대로 보여 준다.
  bool isRefreshing = false;

  int _requestVersion = 0;
  bool _disposed = false;

  /// 요청이 진행 중이면 장르를 바꾸지 못하게 한다. (Required 7)
  bool get isBusy => status == MovieListLoadStatus.loading || isRefreshing;

  /// 장르 ID → 이름. 카드에 "액션 · 2025"처럼 표시할 때 쓴다.
  Map<int, String> get genreNames => {
    for (final genre in genres) genre.id: genre.name,
  };

  /// Discover를 page 1부터 필요한 만큼 요청해 중복 없는 영화를 최대 30개 모은다.
  ///
  /// 한 페이지에 몇 개가 오는지(현재 20개)는 코드에 적지 않는다.
  /// 30개가 모이거나, 마지막 페이지이거나, 빈 페이지가 오면 멈춘다.
  Future<List<TmdbMovieDto>> fetchUpToThirtyMovies({
    List<int>? genreIds,
  }) async {
    // Key를 TMDB id로 두면 페이지 사이에 같은 영화가 또 와도 하나만 남는다.
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < maxMovies && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreIds: genreIds,
      );

      for (final movie in page.results) {
        byId[movie.id] = movie;
        if (byId.length == maxMovies) break;
      }

      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }

    return byId.values.take(maxMovies).toList();
  }

  /// 화면에 처음 들어왔을 때: 장르 목록과 영화 목록을 함께 불러온다.
  Future<void> loadInitial() async {
    final version = ++_requestVersion;
    status = MovieListLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      // 두 요청은 서로의 결과가 필요 없으므로 동시에 시작한다.
      final results = await Future.wait([
        _service.fetchGenres(),
        fetchUpToThirtyMovies(genreIds: selectedGenreIds),
      ]);
      if (_isStale(version)) return;

      genres = results[0] as List<TmdbGenreDto>;
      _applyMovies(results[1] as List<TmdbMovieDto>);
    } catch (error) {
      if (_isStale(version)) return;
      _applyError(error, fallback: '영화를 불러오지 못했어요. 다시 시도해 주세요.');
    }

    notifyListeners();
  }

  /// 장르 Chip 하나를 눌렀을 때.
  ///
  /// null("전체")이면 선택을 비우고, 이미 그 장르만 선택된 상태에서 다시 누르면 해제한다.
  Future<void> selectGenre(int? genreId) {
    final isOnlySelected =
        selectedGenreIds.length == 1 && selectedGenreIds.first == genreId;
    final next = genreId == null || isOnlySelected ? <int>[] : [genreId];
    return selectGenres(next);
  }

  /// 장르 선택을 바꾸고 목록을 처음부터 다시 요청한다.
  ///
  /// BottomSheet의 다중 선택도 이 메서드를 쓴다. (Challenge)
  Future<void> selectGenres(List<int> genreIds) async {
    // 요청 중에는 장르를 바꾸지 못한다. Widget도 Chip을 비활성화하지만 여기서도 막는다.
    if (isBusy) return;

    selectedGenreIds = List.unmodifiable(genreIds);
    await _reloadMovies(fallback: '해당 장르 영화를 불러오지 못했어요.');
  }

  /// Error 화면의 "다시 시도". 마지막으로 선택한 장르 조건 그대로 처음부터 다시 요청한다.
  Future<void> retry() {
    // 장르 목록조차 못 받았다면 처음 진입과 같은 요청을 다시 한다.
    if (genres.isEmpty) return loadInitial();
    return _reloadMovies(fallback: '영화를 불러오지 못했어요. 다시 시도해 주세요.');
  }

  /// 당겨서 새로고침. (Challenge)
  ///
  /// 기존 목록은 지우지 않고 유지하다가, 성공하면 최신 목록으로 바꾼다.
  /// 실패하면 목록을 그대로 두고 false를 돌려주어 화면이 재시도 Dialog를 띄우게 한다.
  Future<bool> refresh() async {
    // Loading 중에는 새로고침하지 않는다. (Loading 화면에는 RefreshIndicator도 없다)
    if (status == MovieListLoadStatus.loading) return true;

    final version = ++_requestVersion;
    isRefreshing = true;
    notifyListeners();

    try {
      final result = await fetchUpToThirtyMovies(genreIds: selectedGenreIds);
      if (_isStale(version)) return true;

      isRefreshing = false;
      _applyMovies(result);
      notifyListeners();
      return true;
    } catch (error) {
      if (_isStale(version)) return true;

      isRefreshing = false;
      message = tmdbErrorMessage(error, fallback: '영화 목록을 새로고침하지 못했어요.');
      notifyListeners();
      return false;
    }
  }

  /// 장르가 바뀌면 이전 목록을 비우고 Loading부터 다시 시작한다.
  Future<void> _reloadMovies({required String fallback}) async {
    final version = ++_requestVersion;
    movies = const [];
    status = MovieListLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final result = await fetchUpToThirtyMovies(genreIds: selectedGenreIds);
      if (_isStale(version)) return;
      _applyMovies(result);
    } catch (error) {
      if (_isStale(version)) return;
      _applyError(error, fallback: fallback);
    }

    notifyListeners();
  }

  void _applyMovies(List<TmdbMovieDto> result) {
    movies = result;
    // 결과가 30개보다 적은 것은 오류가 아니다. 있는 만큼만 보여 준다.
    status = result.isEmpty
        ? MovieListLoadStatus.empty
        : MovieListLoadStatus.success;
  }

  void _applyError(Object error, {required String fallback}) {
    status = MovieListLoadStatus.error;
    message = tmdbErrorMessage(error, fallback: fallback);
  }

  /// 화면이 사라졌거나, 이 요청보다 나중에 시작한 요청이 있으면 결과를 버린다.
  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
