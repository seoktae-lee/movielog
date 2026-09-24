import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/mock_movies.dart';
import 'models/movie.dart';
import 'theme/app_text_styles.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/featured_movie_card.dart';
import 'widgets/horizontal_movie_list.dart';
import 'widgets/section_header.dart';

/// 3주차 홈 화면. 대표 영화 하나와 가로 목록 두 줄로 구성한다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// 상세로 갈 때는 push를 쓴다. 홈이 Stack에 남아 있어야 상세에서 pop으로 돌아올 수 있다.
  void _openDetail(BuildContext context, Movie movie) {
    context.push('/movies/${movie.id}');
  }

  @override
  Widget build(BuildContext context) {
    final featured = movies.first;

    // 원본 movies는 const라 정렬할 수 없으므로 복사본을 만들어 정렬한다.
    final popular = [...movies]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final recent = [...movies]..sort((a, b) => b.year.compareTo(a.year));

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
          FeaturedMovieCard(
            movie: featured,
            onTap: () => _openDetail(context, featured),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: '지금 인기 있는 영화',
            // 탭 화면 사이의 이동은 go로 현재 위치 자체를 바꾼다.
            onSeeAll: () => context.go('/movies'),
          ),
          const SizedBox(height: 8),
          HorizontalMovieList(
            movies: popular,
            onMovieTap: (movie) => _openDetail(context, movie),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: '최근 개봉'),
          const SizedBox(height: 8),
          HorizontalMovieList(
            movies: recent,
            onMovieTap: (movie) => _openDetail(context, movie),
          ),
        ],
      ),
    );
  }
}
