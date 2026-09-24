import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 홈과 영화 목록이 함께 쓰는 영화 카드.
///
/// 포스터·제목·장르·연도만 그리고, 눌렀을 때 무엇을 할지는 [onTap]으로 부모가 정한다.
/// 부모가 높이를 정해 주는 자리(가로 ListView, GridView 셀)에서 쓰는 것을 전제로 한다.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.width,
  });

  final Movie movie;
  final VoidCallback onTap;

  /// 가로 ListView에서는 너비를 고정해야 하고, GridView에서는 null로 두어 셀 너비를 따른다.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // opaque: 카드 안의 빈 여백을 눌러도 Tap으로 인식한다.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 포스터가 남는 세로 공간을 모두 차지하고, 아래 글자 두 줄은 고정 높이를 가진다.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(movie.posterAsset, fit: BoxFit.cover),
                    if (movie.rating != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _RatingBadge(rating: movie.rating!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${movie.genre} · ${movie.year}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 포스터 위에 겹쳐 그리는 작은 평점 배지.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 12, color: Colors.amber),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
