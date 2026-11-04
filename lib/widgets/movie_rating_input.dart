import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../theme/app_colors.dart';

/// 사용자가 별을 눌러 평점을 고르는 입력 위젯.
///
/// 어떻게 입력할지만 담당하고, 고른 값은 [onChanged]로 부모에게 넘겨 부모가 상태를 가진다.
///
/// 7주차 서버 연동 모드: v6 score는 1~5 **정수**다. 반 점을 조용히 toInt()로 깎지 않도록
/// [allowHalfRating]을 끄고 별 한 개 단위로만 고르게 한다.
/// RatingBar는 여전히 double(1.0, 2.0 …)을 돌려주므로, 서버로 보내기 전 `validateServerScore`로 한 번 더 확인한다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  /// 저장 중에는 false로 받아 별을 바꾸지 못하게 한다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: 40,
      glow: false,
      itemBuilder: (context, index) =>
          const Icon(Icons.star, color: AppColors.violet),
      onRatingUpdate: onChanged,
    );
  }
}
