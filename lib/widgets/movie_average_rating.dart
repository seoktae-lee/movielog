import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../theme/app_text_styles.dart';

/// 저장된 평점을 읽기 전용으로 보여 준다.
///
/// 입력용 [RatingBar.builder]와 달리 [RatingBarIndicator]는 4.3처럼 0.5 단위가 아닌 값도 그대로 그린다.
class MovieAverageRating extends StatelessWidget {
  const MovieAverageRating({
    super.key,
    required this.rating,
    this.itemSize = 24,
  });

  /// null이면 아직 평점이 없는 영화다.
  final double? rating;
  final double itemSize;

  @override
  Widget build(BuildContext context) {
    final rating = this.rating;
    if (rating == null) {
      return const Text('아직 평점이 없어요', style: AppTextStyles.bodySmall);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBarIndicator(
          rating: rating,
          itemCount: 5,
          itemSize: itemSize,
          itemBuilder: (context, index) {
            return const Icon(Icons.star, color: Colors.amber);
          },
        ),
        const SizedBox(width: 8),
        Text(rating.toStringAsFixed(1), style: AppTextStyles.titleMedium),
        const Text(' / 5', style: AppTextStyles.bodySmall),
      ],
    );
  }
}
