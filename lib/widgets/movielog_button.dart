import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 앱 전체에서 함께 쓰는 공용 버튼.
///
/// 상태 세 가지를 한 곳에서 표현한다.
/// - 기본: [onPressed]가 있고 [isLoading]이 false
/// - 통신 중: [isLoading]이 true → 회색 배경 + 가운데 인디케이터만, 누를 수 없음
/// - 비활성: [onPressed]가 null → 회색 배경, 누를 수 없음
///
/// 이 Widget은 상태를 "표시"만 하고 스스로 바꾸지 않는다.
/// 지금 통신 중인지, 누를 수 있는지는 ViewModel이 정해서 View가 전달한다.
///
/// [width]
/// - null: 내용(label) 길이만큼 (입력창 옆 보조 버튼)
/// - double.infinity: 부모가 허용하는 최대 너비 (Form 아래 제출 버튼)
/// - 고정 값: 항상 같은 크기
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;

  /// 통신 중이면 onPressed가 있어도 비활성으로 본다. (중복 요청 방지)
  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          disabledBackgroundColor: AppColors.gray,
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // label과 인디케이터를 동시에 그리지 않고 하나만 고른다.
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
