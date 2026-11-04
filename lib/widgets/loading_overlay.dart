import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// [child] 위에 어두운 ModalBarrier와 가운데 흰색 인디케이터를 겹친다. (다중 삭제 Challenge)
///
/// 흰색 카드나 로딩 문구는 띄우지 않는다. 화면 이탈은 바깥의 PopScope가 막는다.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          const ModalBarrier(dismissible: false, color: Colors.black45),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.white),
          ),
      ],
    );
  }
}
