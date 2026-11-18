import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../view_models/favorite_detail_view_model.dart';

/// 영화 상세의 제목·정보 텍스트 오른쪽에 두는 북마크 버튼. (9주차)
///
/// 상태는 [FavoriteDetailViewModel]이 갖는다. 이 Widget은 그리기만 하고,
/// 결과는 3주차처럼 Snackbar로 안내한다. 문구는 mock이 아니라 **서버 요청 결과**를 따른다.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key});

  Future<void> _toggle(BuildContext context, FavoriteDetailViewModel vm) async {
    await vm.toggle();
    if (!context.mounted) return;
    final message =
        vm.errorMessage ?? (vm.isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteDetailViewModel>(
      builder: (context, vm, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 62,
              height: 48,
              // 등록·해제 중에는 북마크 자리에만 인디케이터를 보여 주고 누를 수 없다.
              child: vm.isLoading || vm.isSaving
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.violet,
                        ),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('favorite-button'),
                      color: AppColors.violet,
                      tooltip: vm.isFavorite ? '즐겨찾기 삭제' : '즐겨찾기 추가',
                      onPressed: vm.hasLoadedStatus
                          ? () => _toggle(context, vm)
                          : null,
                      icon: Icon(
                        vm.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
            ),
            const Text('즐겨찾기', style: TextStyle(fontSize: 12)),
            // 첫 여부 조회에 실패했을 때만 북마크와 같은 너비의 새로고침 버튼을 보여 준다.
            if (!vm.hasLoadedStatus && !vm.isLoading)
              SizedBox(
                width: 62,
                child: IconButton(
                  key: const ValueKey('favorite-reload'),
                  tooltip: '여부 다시 확인',
                  color: AppColors.violet,
                  onPressed: vm.load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
          ],
        );
      },
    );
  }
}
