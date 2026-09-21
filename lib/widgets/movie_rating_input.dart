import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// 사용자가 별을 눌러 평점을 고르는 입력 위젯.
///
/// 어떻게 입력할지만 담당하고, 고른 값은 [onChanged]로 부모에게 넘겨 부모가 상태를 가진다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      // 0.5점 단위로 고를 수 있고, 최소 0.5점이다.
      minRating: 0.5,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: 40,
      glow: false,
      itemBuilder: (context, index) {
        return const Icon(Icons.star, color: Colors.amber);
      },
      onRatingUpdate: onChanged,
    );
  }
}
