import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import 'movie_average_rating.dart';
import 'tmdb_poster_image.dart';

/// 마이페이지 "내가 남긴 평점"의 한 줄.
///
/// 별점·코멘트는 MovieLog 서버에서, 제목·포스터는 TMDB에서 온다.
class MyRatingTile extends StatelessWidget {
  const MyRatingTile({super.key, required this.item, required this.onTap});

  final MyRatingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rating = item.rating;
    final movie = item.movie;
    final date = rating.createdAt;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TmdbPosterImage(
                posterPath: movie?.posterPath,
                width: 60,
                height: 90,
                size: 'w185',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // TMDB 정보를 못 받아도 어떤 영화인지 id로는 알 수 있게 한다.
                    movie?.title ?? 'TMDB 영화 #${rating.movieId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MovieAverageRating(
                    rating: rating.score.toDouble(),
                    itemSize: 16,
                  ),
                  if (rating.comment case final comment?
                      when comment.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.black,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      'movieId ${rating.movieId}',
                      if (date != null)
                        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                    ].join(' · '),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
