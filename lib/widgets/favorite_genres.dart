import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 선호 장르를 Chip으로 나열한다.
class FavoriteGenres extends StatelessWidget {
  const FavoriteGenres({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('선호하는 장르', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Chip(
              label: Text(
                '드라마',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.violet,
                ),
              ),
              backgroundColor: AppColors.violetLight,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                'SF',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.violet,
                ),
              ),
              backgroundColor: AppColors.violetLight,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                '애니메이션',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.violet,
                ),
              ),
              backgroundColor: AppColors.violetLight,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
