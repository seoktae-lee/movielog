import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 홈·마이페이지의 섹션 제목. [onSeeAll]을 주면 오른쪽에 '전체보기'가 생긴다.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                '전체보기',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.violet,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
