import 'package:flutter/material.dart';

/// 가입하기 버튼. [onPressed]가 null이면 비활성 상태로 그려진다.
class SignUpButton extends StatelessWidget {
  const SignUpButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: const Text('가입하기'),
    );
  }
}
