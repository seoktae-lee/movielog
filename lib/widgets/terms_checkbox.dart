import 'package:flutter/material.dart';

/// 필수 약관 동의 Checkbox.
///
/// 선택 상태는 부모가 소유하고, 변경은 [onChanged]로 부모에게 알린다.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: const Text('서비스 이용약관에 동의합니다. (필수)'),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}
