import 'package:flutter/material.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_average_rating.dart';
import 'tmdb_poster_image.dart';

/// "내가 등록한 평점"의 카드 한 장.
///
/// 점수·후기·등록일은 자체 백엔드에서, 제목·포스터는 TMDB에서 온다.
/// TMDB에서 영화를 못 찾으면 placeholder를 그리고 평점 기록은 그대로 보여 준다.
///
/// 7주차: 카드 오른쪽에 개별 수정·삭제 버튼. 편집 모드([selected]가 null이 아님)에서는 그 자리에 CheckBox.
/// 이 목록은 `memberId`(나)의 평점만 받으므로 모든 카드가 본인 평점이다.
/// [onEdit]/[onDelete]를 주지 않으면 버튼을 그리지 않는다.
class MyRatingTile extends StatelessWidget {
  const MyRatingTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.selected,
  });

  final RatingWithMovie entry;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// null이면 기본 모드(수정·삭제 버튼), true/false면 편집 모드의 체크 상태.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    // 서버는 UTC(Z)로 준다. 화면에는 기기 시간대 날짜로 보여 준다.
    final date = rating.createdAt.toLocal();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.gray.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // movie가 null이면 posterPath도 null → TmdbPosterImage가 placeholder를 그린다.
                child: TmdbPosterImage(
                  posterPath: movie?.posterPath,
                  width: 60,
                  height: 90,
                  size: 'w185',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // TMDB 정보를 못 받아도 어떤 영화인지 id로는 알 수 있게 한다.
                      movie?.title ?? '영화 #${rating.movieId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 점수: 별 + "4.0 / 5"
                    MovieAverageRating(
                      rating: rating.score.toDouble(),
                      itemSize: 16,
                    ),
                    // comment가 null(또는 빈 문자열)이면 아예 그리지 않는다.
                    if (rating.comment case final comment?
                        when comment.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.black,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${date.year}.${_two(date.month)}.${_two(date.day)} 등록',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              _trailing(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing() {
    final title = entry.movie?.title ?? '영화 #${entry.rating.movieId}';
    if (selected case final isSelected?) {
      return Checkbox(
        value: isSelected,
        activeColor: AppColors.violet,
        semanticLabel: '$title 선택',
        onChanged: (_) => onTap(),
      );
    }
    if (onEdit == null && onDelete == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          IconButton(
            tooltip: '$title 평점 수정',
            icon: const Icon(Icons.edit_outlined, color: AppColors.violet),
            onPressed: onEdit,
          ),
        if (onDelete != null)
          IconButton(
            tooltip: '$title 평점 삭제',
            icon: const Icon(Icons.delete_outline, color: AppColors.gray),
            onPressed: onDelete,
          ),
      ],
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
