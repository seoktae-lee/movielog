import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/mock_movies.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/horizontal_movie_list.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';
import 'widgets/section_header.dart';

/// 3주차 마이페이지. 1주차 프로필 위젯을 그대로 재사용하고 즐겨찾기 목록을 더한다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 즐겨찾기 API는 8주차에 붙인다. 지금은 평점 4.0 이상인 Mock 영화를 즐겨찾기로 본다.
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
          const SectionHeader(title: '즐겨찾기한 영화'),
          const SizedBox(height: 8),
          HorizontalMovieList(
            movies: favorites,
            onMovieTap: (movie) => context.push('/movies/${movie.id}'),
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
