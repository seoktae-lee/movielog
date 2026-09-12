import 'package:flutter/material.dart';

import 'stat_item.dart';

/// 본 영화, 평점, 즐겨찾기 통계를 가로로 나열한다.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: StatItem(label: '본 영화', value: '24'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: StatItem(label: '평점', value: '18'),
        ),
        SizedBox(width: 8),
        Expanded(
          child: StatItem(label: '즐겨찾기', value: '7'),
        ),
      ],
    );
  }
}
