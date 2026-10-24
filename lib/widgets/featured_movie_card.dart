import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import 'tmdb_movie_card.dart';
import 'tmdb_poster_image.dart';

/// 홈 상단에 크게 보여 주는 대표 영화 카드.
///
/// 가로로 넓은 자리라 세로 포스터 대신 TMDB의 `backdrop_path`를 쓰고,
/// 없으면 포스터로, 둘 다 없으면 placeholder로 대신한다.
class FeaturedMovieCard extends StatelessWidget {
  const FeaturedMovieCard({
    super.key,
    required this.movie,
    required this.onTap,
  });

  final TmdbMovieDto movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TmdbPosterImage(
                  posterPath: movie.backdropPath ?? movie.posterPath,
                  size: movie.backdropPath != null ? 'w780' : 'w500',
                ),
                // 아래쪽을 어둡게 깔아 흰 글자가 포스터 위에서도 읽히게 한다.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.violet,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '지금 1위',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        releaseYearOf(movie)?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xDDFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
