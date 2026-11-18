import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import 'movielog_button.dart';

/// 카드 목록 아래의 한 줄: 더 보기 · 추가 로딩 · 다음 page 실패 재시도 · 끝. (9주차)
///
/// [showMoreButton]이 false면 무한 스크롤(Challenge)이다. "더 보기" 버튼 대신 하단 로딩 표시만 보여 주고,
/// 다음 page 호출은 스크롤 위치가 맡는다. 실패했을 때의 재시도 버튼은 어느 쪽이든 보여 준다.
class MoviePageFooter extends StatelessWidget {
  const MoviePageFooter({
    super.key,
    required this.vm,
    this.showMoreButton = true,
  });

  final PagedMoviesViewModel vm;
  final bool showMoreButton;

  @override
  Widget build(BuildContext context) {
    if (!vm.hasMore && !vm.isLoadingMore && vm.loadMoreError == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '더 이상 조회할 페이지가 없습니다.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
      );
    }

    final failed = vm.loadMoreError != null;

    // 무한 스크롤: 실패 전에는 하단 로딩 표시(또는 빈 여백)만 둔다.
    if (!showMoreButton && !failed) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: vm.isLoadingMore
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const SizedBox(height: 24),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (failed) ...[
            Text(
              vm.loadMoreError!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          MovieLogButton(
            width: double.infinity,
            label: failed ? '다음 페이지 다시 시도' : '더 보기',
            // 요청 중에는 버튼이 회색 + 인디케이터가 되어 연속 탭을 막는다.
            isLoading: vm.isLoadingMore,
            onPressed: vm.phase == LoadPhase.ready ? vm.loadNextPage : null,
          ),
        ],
      ),
    );
  }
}
