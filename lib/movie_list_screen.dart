import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/mock_movies.dart';
import 'models/movie.dart';
import 'models/movie_list_initial_data.dart';
import 'services/fake_movie_service.dart';
import 'services/genre_preference.dart';
import 'services/movie_service.dart';
import 'services/sort_preference.dart';
import 'theme/app_colors.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/genre_chips.dart';
import 'widgets/genre_filter_sheet.dart';
import 'widgets/movie_grid.dart';
import 'widgets/movie_list_empty.dart';
import 'widgets/movie_list_error.dart';
import 'widgets/movie_list_loading.dart';

/// 4주차 영화 목록 화면.
///
/// 3주차 화면(URL Query Parameter로 장르 필터)을 그대로 두고 비동기 흐름을 얹었다.
/// - 영화 목록은 [MovieService]가 돌려주는 `Future`로 받고,
///   Loading·Empty·Error·Success 네 상태를 [FutureBuilder]로 나눠 그린다.
/// - Future는 `build`가 아니라 [initState]와 재시도·새로고침 Callback에서만 만든다.
/// - 마지막에 고른 장르와 정렬 기준은 `SharedPreferencesAsync`에 저장했다가
///   앱을 다시 켜면 되살린다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({
    super.key,
    this.selectedGenres = const {},
    this.movieService,
    this.genrePreference,
    this.sortPreference,
  });

  /// Router가 Query Parameter에서 읽어 넘겨 주는 현재 선택 장르. 비어 있으면 전체.
  final Set<String> selectedGenres;

  /// 영화를 가져오는 통로. null이면 4주차용 [FakeMovieService]를 쓴다.
  ///
  /// TODO(5주차 유저별 평점 조회 API): 실제 API를 호출하는 Service를 만들어
  /// 여기(또는 `AppRouter`)에서 넘기는 구현체만 바꾼다. 아래 화면 코드는 그대로 둔다.
  final MovieService? movieService;

  /// 테스트에서 가짜 저장소를 넣기 위한 통로. null이면 실제 기기 저장소를 쓴다.
  final GenrePreference? genrePreference;
  final SortPreference? sortPreference;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late final GenrePreference _genrePreference =
      widget.genrePreference ?? GenrePreference();
  late final SortPreference _sortPreference =
      widget.sortPreference ?? SortPreference();

  /// Mock Service가 어떤 결과를 돌려줄지 고르는 값. (디버그 메뉴 전용)
  MovieLoadMode _mode = MovieLoadMode.success;

  late MovieService _movieService = _createService();

  /// 화면에 적용 중인 정렬 기준. 저장값을 읽으면 그 값으로 바뀐다.
  MovieSortOption _sortOption = MovieSortOption.latest;

  /// FutureBuilder가 지켜볼 Future. build에서 만들지 않고 여기에 보관한다.
  late Future<MovieListInitialData> _initialDataFuture;

  /// 응답을 기다려 줄 최대 시간. (Challenge: Future.timeout)
  static const _timeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    // 화면이 처음 만들어질 때 딱 한 번 요청을 시작한다.
    _initialDataFuture = _startLoad();
  }

  MovieService _createService() =>
      widget.movieService ?? FakeMovieService(mode: _mode);

  /// 새 Future를 만들고, 저장값 복원도 같은 Future에 이어 붙인다.
  Future<MovieListInitialData> _startLoad() {
    final future = _loadInitialData();
    // 결과를 기다렸다가 저장된 장르·정렬을 화면에 되살린다. 실패는 아래에서 삼킨다.
    unawaited(_restoreSavedPreferences(future));
    return future;
  }

  /// 영화 목록과 저장된 설정값을 함께 불러온다.
  ///
  /// 세 작업은 서로의 결과가 필요하지 않으므로 `Future.wait`로 동시에 시작한다.
  /// (한 결과가 다음 작업에 필요하다면 `await`를 순서대로 써야 한다)
  Future<MovieListInitialData> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _movieService.fetchMovies().timeout(_timeout),
        _genrePreference.read(),
        _sortPreference.read(),
      ]);

      return MovieListInitialData(
        movies: results[0] as List<Movie>,
        selectedGenres: results[1] as Set<String>,
        sortOption: results[2] as MovieSortOption,
      );
    } on MovieLoadException catch (error, stackTrace) {
      // 개발자용 기록만 남기고, 화면에 보여 줄 문구는 _errorText가 따로 만든다.
      debugPrint('영화 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      // rethrow: 현재 StackTrace를 유지한 채 그대로 다시 던져 FutureBuilder가 받게 한다.
      rethrow;
    } on TimeoutException catch (error) {
      debugPrint('영화 로드 시간 초과: $error');
      rethrow;
    } finally {
      // 성공·실패와 관계없이 항상 실행된다.
      debugPrint('영화 로드 시도 종료');
    }
  }

  /// 저장돼 있던 장르·정렬을 화면에 되살린다.
  ///
  /// `await` 뒤에서 `setState`와 `context`를 쓰므로 [mounted]를 반드시 확인한다.
  /// (뒤로 가기로 화면이 사라진 뒤 요청이 끝나면 setState() called after dispose()가 난다)
  Future<void> _restoreSavedPreferences(
    Future<MovieListInitialData> future,
  ) async {
    try {
      final data = await future;

      if (!mounted) return;

      if (data.sortOption != _sortOption) {
        setState(() => _sortOption = data.sortOption);
      }

      // URL이 이미 장르를 들고 있으면(뒤로 가기·Deep Link) 그쪽을 존중한다.
      if (widget.selectedGenres.isEmpty && data.selectedGenres.isNotEmpty) {
        await _applyGenres(data.selectedGenres, persist: false);
      }
    } on Exception {
      // 목록을 못 불러온 경우다. 그 사실은 FutureBuilder의 Error 화면이 이미 보여 준다.
    }
  }

  /// 재시도. 이때만 새로운 Future를 만들어 Loading부터 다시 시작한다.
  void _retry() {
    setState(() {
      _initialDataFuture = _startLoad();
    });
  }

  /// 당겨서 새로고침. (Challenge)
  ///
  /// 여기서는 Future를 바로 갈아 끼우지 않고 직접 `await`한다.
  /// 그래야 새로고침이 도는 동안 기존 목록이 그대로 보인다.
  Future<void> _refresh() async {
    try {
      final data = await _loadInitialData();

      // await 뒤에는 화면이 이미 사라졌을 수 있다.
      if (!mounted) return;

      setState(() {
        _sortOption = data.sortOption;
        // 이미 완료된 Future로 바꿔 끼워 FutureBuilder가 새 목록을 그리게 한다.
        _initialDataFuture = Future<MovieListInitialData>.value(data);
      });
    } on Exception catch (error) {
      if (!mounted) return;

      // 새로고침 실패는 화면을 Error로 덮는 대신 Snackbar로만 알린다.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorText(error).message)));
    }
  }

  /// 선택 장르를 저장하고 URL에 실어 같은 화면으로 이동한다.
  Future<void> _applyGenres(Set<String> selected, {bool persist = true}) async {
    if (persist) {
      // 저장이 끝나기 전에 화면이 바뀌지 않도록 await한다.
      await _genrePreference.save(selected);
    }

    if (!mounted) return;

    final location = Uri(
      path: '/movies',
      // 선택이 없으면 Query 자체를 붙이지 않아 '/movies'가 된다.
      queryParameters: selected.isEmpty ? null : {'genre': selected.join(',')},
    ).toString();
    context.go(location);
  }

  /// Chip 한 개 선택: 이미 그 장르만 선택된 상태면 해제, 아니면 그 장르 하나만 선택.
  Future<void> _onChipSelected(String? genre) {
    if (genre == null) return _applyGenres(const {});

    final isOnlySelected =
        widget.selectedGenres.length == 1 &&
        widget.selectedGenres.contains(genre);
    return _applyGenres(isOnlySelected ? const {} : {genre});
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      // DraggableScrollableSheet로 높이를 조절하려면 true여야 한다.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => GenreFilterSheet(
        genres: genres,
        initialSelected: widget.selectedGenres,
      ),
    );

    // 바깥을 눌러 닫으면 null이 온다. await 뒤에는 화면이 살아 있는지 확인한다.
    if (result == null || !mounted) return;
    await _applyGenres(result);
  }

  /// 정렬 기준을 저장하고 화면에 적용한다. (Challenge)
  Future<void> _changeSort(MovieSortOption option) async {
    await _sortPreference.save(option);

    if (!mounted) return;
    setState(() => _sortOption = option);
  }

  /// Mock Service의 결과를 바꾼다. (디버그 메뉴 전용: 네 가지 상태를 직접 재현)
  void _changeMode(MovieLoadMode mode) {
    setState(() {
      _mode = mode;
      _movieService = _createService();
      _initialDataFuture = _startLoad();
    });
  }

  /// 선택 장르로 거르고 정렬 기준으로 정렬한 목록.
  List<Movie> _visibleMovies(List<Movie> loaded) {
    final filtered = widget.selectedGenres.isEmpty
        ? loaded
        : loaded
              .where((movie) => widget.selectedGenres.contains(movie.genre))
              .toList();

    return sortMovies(filtered, _sortOption);
  }

  /// 내부 예외를 사용자가 읽을 수 있는 문구로 바꾼다.
  ///
  /// `SocketException`, StackTrace 같은 내부 정보는 화면에 그대로 내보내지 않는다.
  ({String message, String description}) _errorText(Object? error) {
    if (error is TimeoutException) {
      return (
        message: '응답이 너무 오래 걸려요.',
        description: '네트워크 상태를 확인하고 다시 시도해 주세요.',
      );
    }
    if (error is MovieLoadException) {
      return (message: error.message, description: '잠시 후 다시 시도해 주세요.');
    }
    return (message: '영화를 불러오지 못했습니다.', description: '잠시 후 다시 시도해 주세요.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          PopupMenuButton<MovieSortOption>(
            tooltip: '정렬',
            icon: const Icon(Icons.swap_vert, color: AppColors.black),
            initialValue: _sortOption,
            onSelected: _changeSort,
            itemBuilder: (context) => [
              for (final option in MovieSortOption.values)
                PopupMenuItem(value: option, child: Text(option.label)),
            ],
          ),
          IconButton(
            tooltip: '장르 필터',
            icon: Icon(
              Icons.filter_list,
              color: widget.selectedGenres.isEmpty
                  ? AppColors.black
                  : AppColors.violet,
            ),
            onPressed: _openFilterSheet,
          ),
          // 네 가지 상태를 캡처하기 위한 디버그 전용 메뉴. 배포 빌드에는 들어가지 않는다.
          if (kDebugMode)
            PopupMenuButton<MovieLoadMode>(
              tooltip: 'Mock 응답 모드',
              icon: const Icon(
                Icons.bug_report_outlined,
                color: AppColors.gray,
              ),
              initialValue: _mode,
              onSelected: _changeMode,
              itemBuilder: (context) => [
                for (final mode in MovieLoadMode.values)
                  PopupMenuItem(value: mode, child: Text(mode.label)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          GenreChips(
            genres: genres,
            selectedGenres: widget.selectedGenres,
            onGenreSelected: _onChipSelected,
          ),
          const SizedBox(height: 12),
          Expanded(
            // FutureBuilder는 Future를 실행하는 주체가 아니라,
            // 전달받은 Future의 상태(AsyncSnapshot)를 보고 화면을 고르는 Widget이다.
            child: FutureBuilder<MovieListInitialData>(
              future: _initialDataFuture,
              builder: (context, snapshot) {
                // 1. Loading: future가 연결됐지만 아직 완료되지 않은 상태.
                //    (future가 null인 ConnectionState.none은 여기서 생기지 않는다)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const MovieListLoading();
                }

                // 2. Error: done이라고 항상 데이터가 있는 건 아니다. 오류를 먼저 확인한다.
                if (snapshot.hasError) {
                  final text = _errorText(snapshot.error);
                  return MovieListError(
                    onRetry: _retry,
                    message: text.message,
                    description: text.description,
                  );
                }

                final loaded = snapshot.data?.movies ?? const <Movie>[];

                // 3. Empty(서버가 빈 목록을 준 경우): 오류가 아니라 정상 결과다.
                if (loaded.isEmpty) {
                  return MovieListEmpty(
                    message: '아직 등록된 영화가 없습니다.',
                    description: '새 영화가 등록되면 여기에서 볼 수 있어요.',
                    actionLabel: '다시 불러오기',
                    onAction: _retry,
                  );
                }

                final visible = _visibleMovies(loaded);

                // 3-1. Empty(필터 결과가 없는 경우): 필터를 풀 수 있는 길을 함께 준다.
                if (visible.isEmpty) {
                  return MovieListEmpty(
                    message: '선택한 장르의 영화가 없습니다.',
                    description:
                        '${widget.selectedGenres.join(', ')} 장르에 해당하는 영화가 없어요.',
                    actionLabel: '전체 영화 보기',
                    onAction: () => _applyGenres(const {}),
                  );
                }

                // 4. Success: 3주차 MovieCard를 쓰는 MovieGrid를 그대로 재사용한다.
                return MovieGrid(
                  movies: visible,
                  onRefresh: _refresh,
                  onMovieTap: (movie) => context.push('/movies/${movie.id}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
