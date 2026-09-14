import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 프로필 이미지, 닉네임, 소개를 표시하는 헤더.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // 가로를 꽉 채워서 Column이 가운데 정렬되게
      child: Column(
        children: [
          const CircleAvatar(
            // 원형 프로필 사진
            radius: 44, // 지름 88
            backgroundImage: AssetImage(
              'assets/images/profile/profile_movielog.jpg',
            ),
          ),
          const SizedBox(height: 16), // 사진과 닉네임 사이 간격
          const Text('무비러버', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4), // 닉네임과 소개 사이 간격
          Row(
            mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 → 가운데 정렬 가능
            children: [
              SvgPicture.asset(
                'assets/icons/movie.svg',
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  AppColors.violet, // 검정 SVG를 보라색으로
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 4), // 아이콘과 글자 사이 간격
              const Text('좋아하는 영화를 기록하고 있어요', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
