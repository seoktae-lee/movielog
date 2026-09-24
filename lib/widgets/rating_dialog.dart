import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';

/// 별점을 고르는 커스텀 Dialog.
///
/// 확인을 누르면 고른 평점(double)을 `Navigator.pop`의 결과로 돌려주고,
/// 바깥을 눌러 닫으면 null이 돌아간다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, this.initialRating = 0});

  /// 이미 남긴 평점이 있으면 그 값에서 시작한다.
  final double initialRating;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating;

  // RatingBar는 처음 그려질 때의 initialRating만 읽는다.
  // 초기화할 때 이 값을 바꿔 Key를 새로 주면 위젯이 다시 만들어지며 별이 비워진다.
  int _resetCount = 0;

  void _reset() {
    setState(() {
      _rating = 0;
      _resetCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 0점은 '아직 고르지 않음'으로 취급한다. 별점을 골라야 확인 버튼이 켜진다.
    final hasRating = _rating > 0;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          // 화면 전체 높이가 아니라 내용물 높이만큼만 차지한다.
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('영화는 어떠셨나요?', style: AppTextStyles.titleMedium),
            const SizedBox(height: 24),
            MovieRatingInput(
              key: ValueKey(_resetCount),
              rating: _rating,
              onChanged: (value) {
                setState(() {
                  _rating = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              hasRating ? '${_rating.toStringAsFixed(1)}점' : '별을 눌러 평점을 골라 주세요',
              style: AppTextStyles.bodySmall.copyWith(
                color: hasRating ? AppColors.violet : AppColors.gray,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: hasRating ? _reset : null,
                    child: const Text('초기화'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // 별점이 없으면 null을 넘겨 버튼을 비활성화한다.
                    onPressed: hasRating
                        ? () => Navigator.pop(context, _rating)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
