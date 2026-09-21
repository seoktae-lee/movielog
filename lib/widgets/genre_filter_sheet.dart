import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 장르를 여러 개 고르는 BottomSheet.
///
/// Checkbox를 켜고 끄는 동안에는 Sheet 안의 [_selected]만 바뀌고,
/// 확인을 눌러야 고른 장르 집합이 `Navigator.pop`의 결과로 목록 화면에 전달된다.
class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    super.key,
    required this.genres,
    required this.initialSelected,
  });

  final List<String> genres;
  final Set<String> initialSelected;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  // 부모가 준 집합을 그대로 고치지 않도록 복사본을 만든다.
  late final Set<String> _selected = {...widget.initialSelected};

  void _toggle(String genre, bool? checked) {
    setState(() {
      if (checked ?? false) {
        _selected.add(genre);
      } else {
        _selected.remove(genre);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // false: 부모 높이를 강제로 다 채우지 않고 initialChildSize 비율로 시작한다.
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            // 드래그 손잡이
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Text('장르 필터', style: AppTextStyles.titleMedium),
                  Spacer(),
                  Text('여러 개 선택 가능', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            // 목록만 남은 공간에서 스크롤되고, 아래 확인 버튼은 항상 같은 자리에 남는다.
            Expanded(
              child: ListView.builder(
                // Sheet를 위아래로 끄는 동작과 목록 스크롤을 잇는다.
                controller: scrollController,
                itemCount: widget.genres.length,
                itemBuilder: (context, index) {
                  final genre = widget.genres[index];
                  return CheckboxListTile(
                    value: _selected.contains(genre),
                    onChanged: (checked) => _toggle(genre, checked),
                    title: Text(genre, style: AppTextStyles.bodyMedium),
                    activeColor: AppColors.violet,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? '전체 영화 보기'
                        : '${_selected.length}개 장르 적용',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
