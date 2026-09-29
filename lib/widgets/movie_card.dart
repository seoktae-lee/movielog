import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 홈·영화 목록·마이페이지가 함께 쓰는 영화 카드.
///
/// 포스터를 어떻게 가져오는지(TMDB 이미지인지 asset인지)는 모르고 [poster] Widget을 받아 그린다.
/// 눌렀을 때 무엇을 할지는 [onTap]으로 부모가 정한다.
/// 부모가 높이를 정해 주는 자리(가로 ListView, GridView 셀)에서 쓰는 것을 전제로 한다.
class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.poster,
    required this.title,
    required this.subtitle,
    this.rating,
    this.onTap,
    this.width,
  });

  final Widget poster;
  final String title;

  /// "액션 · 2025"처럼 제목 아래 한 줄. 비어 있으면 그리지 않는다.
  final String subtitle;

  /// 포스터 오른쪽 위 배지에 표시할 평점. null이면 배지를 그리지 않는다.
  final double? rating;
  final VoidCallback? onTap;

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
                    poster,
                    if (rating != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _RatingBadge(rating: rating!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
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
