import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/favorite_list_item.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/load_phase.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movielog_button.dart';
import '../widgets/movie_grid.dart';
import '../widgets/tmdb_movie_card.dart';

/// 마이페이지 → 내 즐겨찾기. (9주차)
///
/// 화면이 다루는 상태는 네 가지로 서로 다르게 보인다.
/// - 목록: 기존 영화 카드([TmdbMovieCard])를 그대로 재사용
/// - 빈 목록: 오류가 아니라 정상 결과
/// - 조회 오류(전체 실패): 다시 시도
/// - 영화 정보 한 건 실패: 그 카드만 placeholder + "정보 재조회", 나머지 카드는 그대로
///
/// 카드를 눌러 상세에서 해제하고 돌아오면 [FavoritesViewModel.refresh]로 목록을 다시 조회한다.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // build()에서는 조회하지 않는다. 첫 프레임 뒤에 한 번만 요청한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  Future<void> _open(FavoritesViewModel vm, TmdbMovieDto movie) async {
    await widget.onOpenMovie(movie);
    if (!mounted) return;
    // 상세에서 해제했을 수 있으므로 돌아오면 다시 조회한다. (ViewModel도 같은 세션인지 다시 확인한다)
    await vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 즐겨찾기'), centerTitle: true),
      body: Consumer<FavoritesViewModel>(
        builder: (context, vm, _) {
          switch (vm.phase) {
            case LoadPhase.idle:
            case LoadPhase.loading:
              return const MovieListLoading();
            case LoadPhase.empty:
              return const MovieListEmpty(
                message: '아직 즐겨찾기한 영화가 없어요.',
                description: '영화 상세에서 북마크를 눌러 추가해 보세요.',
              );
            case LoadPhase.error:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.gray,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        vm.errorMessage ?? '조회 오류입니다.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      MovieLogButton(
                        label: '다시 시도',
                        width: 160,
                        onPressed: vm.refresh,
                      ),
                    ],
                  ),
                ),
              );
            case LoadPhase.ready:
              return RefreshIndicator(
                onRefresh: vm.refresh,
                child: GridView.builder(
                  padding: movieGridPadding,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: movieGridDelegate,
                  itemCount: vm.items.length,
                  itemBuilder: (context, index) {
                    final item = vm.items[index];
                    final movie = item.movie;
                    if (movie == null) {
                      return _MissingMovieCard(
                        item: item,
                        onRetry: () => vm.retryMovie(item.favorite.favoriteId),
                      );
                    }
                    return TmdbMovieCard(
                      key: ValueKey(item.favorite.favoriteId),
                      movie: movie,
                      onTap: () => _open(vm, movie),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

/// TMDB에서 영화 정보를 받지 못한 카드. 제목·포스터 대신 `영화 #movieId`와 재조회 버튼을 보여 준다.
class _MissingMovieCard extends StatelessWidget {
  const _MissingMovieCard({required this.item, required this.onRetry});

  final FavoriteListItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.violetLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: AppColors.gray,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '영화 #${item.favorite.movieId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          item.errorMessage ?? '정보가 없습니다.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 4),
        MovieLogButton(
          label: '정보 재조회',
          width: double.infinity,
          isLoading: item.isRetrying,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
