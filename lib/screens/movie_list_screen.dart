import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/genre_chips.dart';
import '../widgets/genre_filter_sheet.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movie_page_footer.dart';

/// 영화 목록 화면.
///
/// 5주차에는 Discover를 여러 번 불러 최대 30개를 한 번에 모았다.
/// 9주차부터는 [PagedMoviesViewModel]이 **한 page씩** 가져온다. 카드 아래 footer의 "더 보기"(또는
/// 무한 스크롤)로 다음 page를 붙이고, 장르가 바뀌면 목록을 비우고 첫 page부터 다시 요청한다.
/// AppBar 오른쪽 검색 아이콘은 `/movies/search`로 이동한다.
///
/// State가 필요한 이유: 새로고침 실패 Dialog에서 재시도할 때 RefreshIndicator를 코드로 다시 띄우기 위한
/// [GlobalKey]와, 무한 스크롤(Challenge)이 스크롤 위치를 읽는 [ScrollController]를 보관해야 한다.
class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key, this.infiniteScroll = kInfiniteScroll});

  /// true면 무한 스크롤(Challenge), false면 "더 보기" 버튼(Required).
  final bool infiniteScroll;

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

/// Challenge B(무한 스크롤). false로 실행하면(`--dart-define=INFINITE_SCROLL=false`)
/// Required의 "더 보기" 버튼 방식이 된다. 기본값은 Challenge까지 적용한 무한 스크롤이다.
const kInfiniteScroll = bool.fromEnvironment(
  'INFINITE_SCROLL',
  defaultValue: true,
);

/// 끝까지 남은 스크롤 거리가 이 값 이하가 되면 다음 page를 요청한다.
const _loadMoreExtent = 400.0;

class _MovieListScreenState extends State<MovieListScreen> {
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.infiniteScroll) _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// 끝에 가까워지면 다음 page를 부른다. 중복 요청은 ViewModel의 isLoadingMore가 막는다.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter <= _loadMoreExtent) {
      context.read<PagedMoviesViewModel>().loadNextPage();
    }
  }

  void _openDetail(TmdbMovieDto movie) {
    // 이미 받은 DTO는 extra로 넘기고, URL에는 목록 index가 아니라 TMDB id를 싣는다.
    context.push('/movies/${movie.id}', extra: movie);
  }

  /// 당겨서 새로고침. 실패하면 기존 목록을 둔 채 재시도 Dialog를 띄운다. (Challenge)
  Future<void> _onRefresh() async {
    final viewModel = context.read<PagedMoviesViewModel>();
    final succeeded = await viewModel.refresh();

    if (succeeded || !mounted) return;
    // Dialog를 await하면 닫힐 때까지 새로고침 스피너가 계속 돈다.
    // 새로고침은 여기서 끝내고, Dialog는 그 뒤에 따로 띄운다.
    unawaited(_showRetryDialog('영화 목록을 새로고침하지 못했어요.'));
  }

  Future<void> _showRetryDialog(String? message) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('영화 목록을 불러오지 못했어요'),
        content: Text('${message ?? '잠시 후 다시 시도해 주세요.'}\n지금 보이는 목록은 그대로 유지돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
            child: const Text('재시도'),
          ),
        ],
      ),
    );

    if (retry != true || !mounted) return;
    // 같은 장르 조건으로 page 1부터 다시. 스피너도 함께 보이도록 RefreshIndicator로 시작한다.
    await _refreshIndicatorKey.currentState?.show();
  }

  Future<void> _openFilterSheet() async {
    final viewModel = context.read<PagedMoviesViewModel>();

    final result = await showModalBottomSheet<List<int>>(
      context: context,
      // DraggableScrollableSheet로 높이를 조절하려면 true여야 한다.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => GenreFilterSheet(
        genres: viewModel.genres,
        initialSelected: viewModel.selectedGenreIds,
      ),
    );

    // 바깥을 눌러 닫으면 null이 온다. await 뒤에는 화면이 살아 있는지 확인한다.
    if (result == null || !mounted) return;
    await viewModel.selectGenres(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            tooltip: '영화 검색',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/movies/search'),
          ),
          // 필터 버튼만 상태에 따라 켜고 끈다.
          Consumer<PagedMoviesViewModel>(
            builder: (context, viewModel, child) {
              final canFilter =
                  !viewModel.isBusy && viewModel.genres.isNotEmpty;
              return IconButton(
                tooltip: '장르 필터',
                icon: Icon(
                  Icons.filter_list,
                  color: viewModel.selectedGenreIds.isEmpty
                      ? AppColors.black
                      : AppColors.violet,
                ),
                onPressed: canFilter ? _openFilterSheet : null,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Consumer<PagedMoviesViewModel>(
            builder: (context, viewModel, child) => GenreChips(
              genres: viewModel.genres,
              selectedGenreIds: viewModel.selectedGenreIds,
              // 요청 중에는 장르를 바꾸지 못한다. (Required 7)
              enabled: !viewModel.isBusy,
              onGenreSelected: (genreId) =>
                  context.read<PagedMoviesViewModel>().selectGenre(genreId),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            // 상태가 바뀌면 이 Consumer의 builder만 다시 실행된다.
            child: Consumer<PagedMoviesViewModel>(
              builder: (context, viewModel, child) {
                return switch (viewModel.phase) {
                  LoadPhase.idle ||
                  LoadPhase.loading => const MovieListLoading(),
                  LoadPhase.error => MovieListError(
                    message: viewModel.errorMessage ?? '영화를 불러오지 못했어요.',
                    onRetry: () => context.read<PagedMoviesViewModel>().retry(),
                  ),
                  LoadPhase.empty => MovieListEmpty(
                    message: '조건에 맞는 영화가 없어요.',
                    description: viewModel.selectedGenreIds.isEmpty
                        ? null
                        : '다른 장르를 골라 보세요.',
                    actionLabel: viewModel.selectedGenreIds.isEmpty
                        ? '다시 불러오기'
                        : '전체 영화 보기',
                    onAction: viewModel.selectedGenreIds.isEmpty
                        ? () => context.read<PagedMoviesViewModel>().retry()
                        : () => context
                              .read<PagedMoviesViewModel>()
                              .selectGenres(const []),
                  ),
                  LoadPhase.ready => Column(
                    children: [
                      _MovieCountLabel(count: viewModel.movies.length),
                      Expanded(
                        child: MovieGrid(
                          movies: viewModel.movies,
                          genreNames: viewModel.genreNames,
                          preferredGenreIds: viewModel.selectedGenreIds,
                          refreshIndicatorKey: _refreshIndicatorKey,
                          scrollController: _scrollController,
                          onRefresh: _onRefresh,
                          onMovieTap: _openDetail,
                          footer: MoviePageFooter(
                            vm: viewModel,
                            showMoreButton: !widget.infiniteScroll,
                          ),
                        ),
                      ),
                    ],
                  ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 지금까지 불러온 영화 수. 더 보기·스크롤로 계속 늘어난다.
class _MovieCountLabel extends StatelessWidget {
  const _MovieCountLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '인기순 $count편',
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
