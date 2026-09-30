import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/mock_movies.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/edit_profile_button.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movie_card.dart';
import '../widgets/my_rating_tile.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';
import '../widgets/section_header.dart';

/// 마이페이지. 1주차 프로필 위젯을 그대로 재사용한다.
///
/// 5주차: "내가 남긴 평점"을 MovieLog 서버(`GET /members/{memberId}/ratings`)에서 가져온다.
/// 즐겨찾기는 8주차에 서버와 연결하기 전까지 Mock이다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 즐겨찾기 API는 이후 주차에 붙인다. 지금은 평점 4.0 이상인 Mock 영화를 즐겨찾기로 본다.
    // 5주차부터 상세 화면은 TMDB id로 동작하므로, Mock 영화는 상세로 이동하지 않는다.
    final favorites = movies
        .where((movie) => (movie.rating ?? 0) >= 4.0)
        .toList();

    return Scaffold(
      appBar: const CommonAppBar(title: '마이페이지'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileHeader(),
                SizedBox(height: 24),
                ProfileStats(),
                SizedBox(height: 24),
                FavoriteGenres(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: '내가 남긴 평점'),
          const SizedBox(height: 4),
          const _MyRatingsSection(),
          const SizedBox(height: 24),
          const SectionHeader(title: '즐겨찾기한 영화'),
          const SizedBox(height: 8),
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: favorites.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final movie = favorites[index];
                return MovieCard(
                  width: 136,
                  poster: Image.asset(movie.posterAsset, fit: BoxFit.cover),
                  title: movie.title,
                  subtitle: '${movie.genre} · ${movie.year}',
                  rating: movie.rating,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: EditProfileButton(),
          ),
        ],
      ),
    );
  }
}

/// "내가 남긴 평점" 영역. 이 부분만 ViewModel 상태에 따라 다시 그린다.
class _MyRatingsSection extends StatelessWidget {
  const _MyRatingsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<MyRatingsViewModel>(
      builder: (context, viewModel, child) {
        switch (viewModel.status) {
          case MyRatingsLoadStatus.idle:
          case MyRatingsLoadStatus.loading:
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          case MyRatingsLoadStatus.error:
            return _RatingsMessage(
              message: viewModel.message ?? '평점을 불러오지 못했어요.',
              actionLabel: '다시 시도',
              onAction: () => context.read<MyRatingsViewModel>().load(),
            );
          case MyRatingsLoadStatus.empty:
            return const _RatingsMessage(message: '아직 남긴 평점이 없어요.');
          case MyRatingsLoadStatus.success:
            return Column(
              children: [
                for (final item in viewModel.items)
                  MyRatingTile(
                    item: item,
                    // TMDB id로 상세에 간다. 받은 영화 정보가 있으면 extra로 넘겨 다시 부르지 않는다.
                    onTap: () => context.push(
                      '/movies/${item.rating.movieId}',
                      extra: item.movie,
                    ),
                  ),
              ],
            );
        }
      },
    );
  }
}

class _RatingsMessage extends StatelessWidget {
  const _RatingsMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(color: AppColors.violet),
              ),
            ),
        ],
      ),
    );
  }
}
