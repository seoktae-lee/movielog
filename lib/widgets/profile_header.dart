import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 프로필 이미지, 닉네임, 소개를 표시하는 헤더.
///
/// 8주차: 마이페이지는 GET me로 받은 닉네임·이메일·가입일을 넘긴다.
/// 값을 넘기지 않으면 1주차 정적 프로필 화면처럼 예시 값을 보여 준다.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    this.nickname = '무비러버',
    this.email,
    this.joinedText,
  });

  final String nickname;
  final String? email;

  /// Challenge: "2026.10.10 가입"
  final String? joinedText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // 가로를 꽉 채워서 Column이 가운데 정렬되게
      child: Column(
        children: [
          const CircleAvatar(
            radius: 44, // 지름 88
            backgroundImage: AssetImage(
              'assets/images/profile/profile_movielog.jpg',
            ),
          ),
          const SizedBox(height: 16),
          Text(nickname, style: AppTextStyles.titleLarge),
          if (joinedText case final joined?) ...[
            const SizedBox(height: 2),
            Text(joined, style: AppTextStyles.bodySmall),
          ],
          if (email case final email?) ...[
            const SizedBox(height: 2),
            Text(email, style: AppTextStyles.bodySmall),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/movie.svg',
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  AppColors.violet,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 4),
              const Text('좋아하는 영화를 기록하고 있어요', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
