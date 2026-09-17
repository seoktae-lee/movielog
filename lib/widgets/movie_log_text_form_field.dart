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

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon),
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
