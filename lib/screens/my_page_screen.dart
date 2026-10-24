import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock_movies.dart';
import '../theme/app_colors.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/edit_profile_button.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movie_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';
import '../widgets/section_header.dart';

/// 마이페이지. 1주차 프로필 위젯을 그대로 재사용한다.
///
/// 6주차: "내가 등록한 평점" 진입 행을 두고, 목록은 자식 화면(`MyRatingsScreen`)이 보여 준다.
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
          const SizedBox(height: 16),
          // 6주차: 평점은 자식 화면(/my/ratings)으로 분리했다.
          // push라서 뒤로 가면 마이페이지로 돌아온다.
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.star_outline, color: AppColors.violet),
            title: const Text('내가 등록한 평점'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/my/ratings'),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
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
