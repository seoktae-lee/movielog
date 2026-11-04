import 'package:flutter/material.dart';

/// 회원가입 화면의 입력창 공통 Widget.
///
/// Controller와 FocusNode는 부모 State가 소유하고 dispose하며,
/// 이 Widget은 전달받은 객체를 연결만 한다.
class MovieLogTextFormField extends StatelessWidget {
  const MovieLogTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    required this.validator,
    required this.onChanged,
    required this.onFieldSubmitted,
    this.focusNode,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.suffixIcon,
    this.fieldKey,
    this.helperText,
    this.helperColor,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onFieldSubmitted;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;

  /// 비밀번호 표시·숨김 버튼처럼 입력창 오른쪽에 놓을 Widget.
  final Widget? suffixIcon;

  /// 이 칸만 따로 validate()할 때 쓰는 Key. (중복 확인 전 형식 검사)
  final GlobalKey<FormFieldState<String>>? fieldKey;

  /// 입력창 아래 안내 문구. (예: 사용할 수 있는 닉네임이에요.)
  final String? helperText;
  final Color? helperColor;

  /// 서버가 알려 준 오류처럼 validator 밖에서 정해진 오류 문구.
  final String? errorText;

  /// 제출 중에는 false로 받아 입력을 잠근다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon),
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: helperColor == null ? null : TextStyle(color: helperColor),
        errorText: errorText,
        // 입력창 옆에 버튼이 있어 폭이 좁다. 긴 오류 문구가 잘리지 않게 두 줄까지 허용한다.
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
