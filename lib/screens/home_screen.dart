import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_home_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/featured_movie_card.dart';
import '../widgets/horizontal_movie_list.dart';
import '../widgets/section_header.dart';

/// 5주차 홈 화면. TMDB Popular 결과 중 앞 5개를 보여 준다.
///
/// 이 Widget은 API를 직접 부르지 않는다. [MovieHomeViewModel]의 상태를 읽어 그리기만 하고,
/// 요청은 Route에서 ViewModel을 만들 때(`..loadPopular()`) 한 번만 시작된다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// 상세로 갈 때는 push를 쓴다. 이미 받은 DTO는 extra로 넘기고, URL에는 TMDB id를 싣는다.
  void _openDetail(BuildContext context, TmdbMovieDto movie) {
    context.push('/movies/${movie.id}', extra: movie);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: 'MovieLog'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              '무비러버님,\n오늘은 어떤 영화를 기록할까요?',
              style: AppTextStyles.titleLarge,
            ),
          ),
          // 인기 영화 영역만 상태에 따라 다시 그린다. 위 인사말은 다시 그리지 않는다.
          Consumer<MovieHomeViewModel>(
            builder: (context, viewModel, child) {
              return switch (viewModel.status) {
                MovieHomeLoadStatus.idle ||
                MovieHomeLoadStatus.loading => const _PopularLoading(),
                MovieHomeLoadStatus.error => _PopularMessage(
                  icon: Icons.error_outline,
                  message: viewModel.message ?? '인기 영화를 불러오지 못했어요.',
                  actionLabel: '다시 시도',
                  onAction: () =>
                      context.read<MovieHomeViewModel>().loadPopular(),
                ),
                MovieHomeLoadStatus.empty => const _PopularMessage(
                  icon: Icons.movie_filter_outlined,
                  message: '지금 보여 줄 인기 영화가 없어요.',
                ),
                MovieHomeLoadStatus.success => _PopularSection(
                  movies: viewModel.popularMovies,
                  onMovieTap: (movie) => _openDetail(context, movie),
                ),
              };
            },
          ),
          const SizedBox(height: 24),
          const _TmdbAttribution(),
        ],
      ),
    );
  }
}

/// 1위 영화 크게 + 인기 5개 가로 목록.
class _PopularSection extends StatelessWidget {
  const _PopularSection({required this.movies, required this.onMovieTap});

  final List<TmdbMovieDto> movies;
  final ValueChanged<TmdbMovieDto> onMovieTap;

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeaturedMovieCard(movie: featured, onTap: () => onMovieTap(featured)),
        const SizedBox(height: 24),
        SectionHeader(
          title: '지금 인기 있는 영화',
          // 탭 화면 사이의 이동은 go로 현재 위치 자체를 바꾼다.
          onSeeAll: () => context.go('/movies'),
        ),
        const SizedBox(height: 8),
        HorizontalMovieList(movies: movies, onMovieTap: onMovieTap),
      ],
    );
  }
}

class _PopularLoading extends StatelessWidget {
  const _PopularLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('인기 영화를 불러오는 중이에요', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PopularMessage extends StatelessWidget {
  const _PopularMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.gray),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// TMDB 이용 약관의 출처 표기.
class _TmdbAttribution extends StatelessWidget {
  const _TmdbAttribution();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'This product uses the TMDB API but is not endorsed or certified by TMDB.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.gray),
      ),
    );
  }
}
