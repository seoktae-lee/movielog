import 'package:flutter/material.dart';

import '../models/movie.dart';
import 'movie_card.dart';

/// 영화 카드를 가로로 나열하는 목록.
///
/// 가로 ListView는 높이를 스스로 정하지 못하므로 [SizedBox]로 높이를 고정한다.
class HorizontalMovieList extends StatelessWidget {
  const HorizontalMovieList({
    super.key,
    required this.movies,
    required this.onMovieTap,
  });

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: movies.length,
        // separatorBuilder는 항목 사이에만 호출되므로 마지막 카드 뒤에는 간격이 붙지 않는다.
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final movie = movies[index];
          return MovieCard(
            movie: movie,
            width: 136,
            onTap: () => onMovieTap(movie),
          );
        },
      ),
    );
  }
}
