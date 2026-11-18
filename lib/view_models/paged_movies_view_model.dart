import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/models/tmdb_genre_dto.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../data/models/tmdb_movie_page.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';
import 'tmdb_error_message.dart';

/// 영화 목록과 영화 검색이 함께 쓰는 "한 page씩" 조회 ViewModel. (9주차)
///
/// 5주차 `MovieListViewModel`은 Discover를 여러 번 불러 최대 30개를 한 번에 모았다.
/// 이제는 사용자가 "더 보기"를 누를 때(또는 끝까지 스크롤할 때)마다 **한 page씩** 가져온다.
/// 목록 화면과 검색 화면이 각자 이 클래스의 **별도 인스턴스**를 만든다.
///
/// 상태 규칙:
/// 1. 첫 page 성공 → 기존 목록을 교체
/// 2. 더 보기 → [isLoadingMore]가 true, 기존 카드는 그대로 유지
/// 3. 성공 → 같은 movieId를 뺀 뒤 append하고 [nextPage] 증가
/// 4. 실패 → 목록과 [nextPage]를 그대로 두고 [loadMoreError]만 표시 (같은 page를 다시 요청)
/// 5. 마지막 page → [hasMore]가 false
/// 6. 장르·검색어 변경 → generation을 올리고 목록·page·추가 로딩 상태를 모두 초기화한 뒤 새 첫 page 요청
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel({required this.tmdbApi});

  final TmdbMovieService tmdbApi;

  /// TMDB가 허용하는 page 상한. `total_pages`가 더 커도 501은 요청하지 않는다.
  static const maxTmdbPage = 500;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> movies = [];

  /// 다음에 요청할 page. 실패해도 올리지 않는다.
  int nextPage = 1;

  /// 서버 total_pages와 [maxTmdbPage] 중 작은 값.
  int totalPages = 1;
  bool isLoadingMore = false;
  bool get hasMore => nextPage <= totalPages;

  /// 당겨서 새로고침 중. 이때는 기존 목록을 지우지 않는다.
  bool isRefreshing = false;

  String? errorMessage;

  /// 기존 목록을 지우지 않고 하단에 보여 줄 "다음 page 실패" 문구.
  String? loadMoreError;

  /// 장르 목록(Genre API). 검색 화면에서는 쓰지 않는다.
  List<TmdbGenreDto> genres = const [];

  int _requestGeneration = 0;

  ({List<int> genreIds, String query}) _condition = (
    genreIds: const [],
    query: '',
  );

  List<int> get selectedGenreIds => _condition.genreIds;
  String get query => _condition.query;

  /// 요청 중에는 장르를 바꾸지 못한다.
  bool get isBusy => phase == LoadPhase.loading || isRefreshing;

  /// 장르 ID → 이름. 카드에 "액션 · 2025"처럼 표시할 때 쓴다.
  Map<int, String> get genreNames => {
    for (final genre in genres) genre.id: genre.name,
  };

  /// 장르 목록을 한 번 불러온다. 실패해도 영화 목록은 계속 쓸 수 있다. (장르 이름만 비어 보인다)
  Future<void> loadGenres() async {
    if (genres.isNotEmpty) return;
    try {
      final result = await tmdbApi.fetchGenres();
      if (isDisposed) return;
      genres = result;
      notifyIfAlive();
    } catch (_) {
      // 장르 칩이 없을 뿐 목록 조회와는 무관하다.
    }
  }

  /// 새 조건으로 첫 page부터 다시 불러온다. 이전 조건의 목록·추가 로딩·오류를 모두 지운다.
  Future<void> loadInitial({
    List<int> genreIds = const [],
    String query = '',
  }) async {
    if (isDisposed) return;
    _condition = (genreIds: List.unmodifiable(genreIds), query: query.trim());
    final generation = ++_requestGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    loadMoreError = null;
    isLoadingMore = false;
    isRefreshing = false;
    movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _applyFirstPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      phase = LoadPhase.error;
      errorMessage = tmdbErrorMessage(
        error,
        fallback: _condition.query.isEmpty
            ? '영화 목록을 불러오지 못했습니다.'
            : '검색 결과를 불러오지 못했습니다.',
      );
    } finally {
      if (generation == _requestGeneration && !isDisposed) notifyIfAlive();
    }
  }

  /// 장르 Chip 하나를 눌렀을 때. null("전체")이거나, 이미 그 장르만 선택돼 있으면 선택을 비운다.
  Future<void> selectGenre(int? genreId) {
    final only =
        selectedGenreIds.length == 1 && selectedGenreIds.first == genreId;
    return selectGenres(genreId == null || only ? const [] : [genreId]);
  }

  /// 장르 선택(다중)을 바꾸고 첫 page부터 다시 요청한다. BottomSheet의 확인도 이 메서드를 쓴다.
  Future<void> selectGenres(List<int> genreIds) {
    if (isBusy) return Future.value();
    return loadInitial(genreIds: genreIds, query: _condition.query);
  }

  /// 같은 조건 그대로 첫 page부터 다시 요청한다. (오류 화면의 "다시 시도")
  Future<void> retry() =>
      loadInitial(genreIds: _condition.genreIds, query: _condition.query);

  /// 당겨서 새로고침. 기존 목록은 유지하다가 성공하면 첫 page로 교체한다. 실패하면 false.
  Future<bool> refresh() async {
    if (isDisposed || phase == LoadPhase.loading || isRefreshing) return true;
    final generation = ++_requestGeneration;
    isRefreshing = true;
    isLoadingMore = false;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1, _condition);
      if (generation != _requestGeneration || isDisposed) return true;
      _applyFirstPage(page);
      return true;
    } catch (_) {
      if (generation != _requestGeneration || isDisposed) return true;
      return false;
    } finally {
      if (generation == _requestGeneration && !isDisposed) {
        isRefreshing = false;
        notifyIfAlive();
      }
    }
  }

  /// 다음 page를 한 장 더 가져온다. 실패해도 [nextPage]를 올리지 않아 같은 page를 다시 요청할 수 있다.
  Future<void> loadNextPage() async {
    if (isDisposed ||
        isLoadingMore ||
        isRefreshing ||
        !hasMore ||
        phase != LoadPhase.ready) {
      return;
    }
    final generation = _requestGeneration;
    final pageToLoad = nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(pageToLoad, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _appendPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      loadMoreError = tmdbErrorMessage(
        error,
        fallback: '다음 페이지를 불러오지 못했습니다. 같은 페이지를 다시 요청합니다.',
      );
    } finally {
      if (generation == _requestGeneration && !isDisposed) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  Future<TmdbMoviePageDto> _fetchPage(
    int page,
    ({List<int> genreIds, String query}) condition,
  ) async {
    final result = condition.query.isNotEmpty
        ? await tmdbApi.searchMovies(page: page, query: condition.query)
        : await tmdbApi.discoverMovies(
            page: page,
            genreIds: condition.genreIds,
          );
    if (result.page != page || result.page < 1 || result.totalPages < 0) {
      throw const FormatException('TMDB page metadata is inconsistent.');
    }
    return result;
  }

  void _applyFirstPage(TmdbMoviePageDto page) {
    movies
      ..clear()
      ..addAll(_dedupe(page.results));
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
    phase = movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
  }

  void _appendPage(TmdbMoviePageDto page) {
    movies.addAll(_dedupe(page.results));
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
  }

  /// TMDB는 page가 바뀌어도 같은 영화가 다시 내려올 수 있다. 이미 가진 movieId는 뺀다.
  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = movies.map((movie) => movie.id).toSet();
    return incoming
        .where((movie) => seen.add(movie.id))
        .toList(growable: false);
  }
}
