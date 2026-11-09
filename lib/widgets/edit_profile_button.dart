import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 프로필 수정 버튼.
///
/// 1주차에는 모양만 있었다. 8주차부터 마이페이지가 [onPressed]로 `/my/profile/edit`를 연다.
/// [onPressed]가 null이면 비활성(내 정보를 아직 못 받았을 때).
class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key, this.onPressed = _logTap});

  final VoidCallback? onPressed;

  static void _logTap() => debugPrint('프로필 수정 버튼을 눌렀습니다.');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          '프로필 수정',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
