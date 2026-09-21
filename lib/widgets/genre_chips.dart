import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 영화 목록 상단의 장르 선택 Chip 줄.
///
/// 맨 앞의 '전체' Chip은 [onGenreSelected]에 null을 넘긴다.
class GenreChips extends StatelessWidget {
  const GenreChips({
    super.key,
    required this.genres,
    required this.selectedGenres,
    required this.onGenreSelected,
  });

  final List<String> genres;
  final Set<String> selectedGenres;
  final ValueChanged<String?> onGenreSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // '전체' Chip 하나를 앞에 더한다.
        itemCount: genres.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GenreChip(
              label: '전체',
              selected: selectedGenres.isEmpty,
              onSelected: () => onGenreSelected(null),
            );
          }
          final genre = genres[index - 1];
          return _GenreChip(
            label: genre,
            selected: selectedGenres.contains(genre),
            onSelected: () => onGenreSelected(genre),
          );
        },
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: selected ? AppColors.violet : AppColors.gray,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: AppColors.violetLight,
      backgroundColor: AppColors.white,
      side: BorderSide(
        color: selected ? AppColors.violetLight : const Color(0xFFE0DDE4),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
