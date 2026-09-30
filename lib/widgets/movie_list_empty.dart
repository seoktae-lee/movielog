import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 영화 목록의 Empty 화면.
///
/// 빈 목록은 오류가 아니라 정상 결과이므로, 오류 화면과 말투도 생김새도 다르게 둔다.
/// 빈 Grid를 그대로 보여 주는 대신 무엇이 비었는지와 다음에 할 수 있는 행동을 알려 준다.
class MovieListEmpty extends StatelessWidget {
  const MovieListEmpty({
    super.key,
    this.message = '조건에 맞는 영화가 없습니다.',
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? description;

  /// 사용자가 바로 할 수 있는 행동. (예: 필터 해제)
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.movie_filter_outlined,
              size: 48,
              color: AppColors.gray,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.violet,
                  side: const BorderSide(color: AppColors.violetLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
