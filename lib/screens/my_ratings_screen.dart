import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/rating_dto.dart';
import '../data/services/rating_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movielog_button.dart';
import '../widgets/my_rating_tile.dart';
import '../widgets/rating_dialog.dart';

/// 마이페이지 → "내가 등록한 평점" 자식 화면.
///
/// root Navigator 위에 push되므로 하단 NavigationBar가 없다.
/// 8주차: 이번 로그인 세션에서 등록한 평점(v7 등록 result)을 보여 주고, 카드마다 v7 PATCH·DELETE로 수정·삭제한다.
/// v7에는 토큰 기반 "내 평점 전체 조회"가 없어 앱 재시작 뒤 이전 평점은 복원하지 않는다.
/// 상단 "편집"으로 다중 선택 모드에 들어가 여러 개를 한 번에 지울 수 있다. (Challenge)
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyRatingsViewModel>();
    final isEditMode = viewModel.isEditMode;
    final selectedCount = viewModel.selectedRatingIds.length;

    // 다중 삭제 중에는 뒤로가기를 막고, 화면 전체(AppBar 포함)를 오버레이로 덮는다.
    return PopScope(
      canPop: !viewModel.isDeletingSelected,
      child: LoadingOverlay(
        isLoading: viewModel.isDeletingSelected,
        child: Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('내가 등록한 평점'),
            centerTitle: true,
          ),
          // bottomNavigationBar 자리에는 편집 모드일 때만 "선택한 N개 삭제" 버튼을 둔다.
          bottomNavigationBar: isEditMode
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: MovieLogButton(
                      label: '선택한 $selectedCount개 삭제',
                      width: double.infinity,
                      onPressed: selectedCount > 0
                          ? () => onDeleteSelectedPressed(context)
                          : null,
                    ),
                  ),
                )
              : null,
          body: switch (viewModel.status) {
            MyRatingsLoadStatus.idle ||
            MyRatingsLoadStatus.loading => const _RatingsLoading(),
            MyRatingsLoadStatus.empty => const MovieListEmpty(
              message: '이번 로그인에서 등록한 평점이 없습니다.',
              description: '영화 상세에서 평점을 남기면 여기에 표시돼요.\n'
                  '앱을 다시 시작하면 이전 평점은 표시되지 않아요. (v7 API 한계)',
            ),
            MyRatingsLoadStatus.success => _RatingsList(viewModel: viewModel),
          },
        ),
      ),
    );
  }
}

/// 카드의 수정 버튼 → 기존 별점·코멘트가 채워진 RatingDialog.
///
/// Dialog 안에서 값을 바꾸는 동안 실제 rating 객체는 건드리지 않으므로 취소 시 복구 로직이 필요 없다.
/// updateRating이 쓰기 실패를 rethrow하면 Dialog가 열린 채 서버 message를 보여 준다.
Future<void> onEditPressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
    builder: (_) => RatingDialog(
      initialScore: rating.score,
      initialComment: rating.comment, // null이면 TextField가 빈 칸으로 시작한다.
      onSubmit: (score, comment) => viewModel.updateRating(
        ratingId: rating.ratingId,
        score: score,
        comment: comment,
      ),
    ),
  );

  if (!context.mounted || saved != true) return;
  _showSnackBar(context, '평점을 수정했습니다.');
}

/// 카드의 삭제 버튼 → 확인 Dialog. 단건 삭제는 요청이 끝날 때까지 Dialog를 유지한다.
Future<void> onDeletePressed(BuildContext context, RatingDto rating) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 삭제 중 바깥 탭으로 닫히는 것도 막는다.
    builder: (_) => _DeleteRatingDialog(
      title: '평점을 삭제할까요?',
      onConfirm: () => viewModel.deleteRating(rating.ratingId),
    ),
  );
  // deleted는 실제로 삭제까지 마쳤을 때만 true다. 취소면 요청을 보내지 않았다.
  if (!context.mounted || deleted != true) return;
  _showSnackBar(context, '평점을 삭제했습니다.');
}

/// "선택한 N개 삭제" → 확인 Dialog는 삭제 여부만 묻고 **요청 전에** 닫힌다.
/// 삭제 중 로딩은 Dialog가 아니라 화면 위 Stack 오버레이가 보여 준다.
Future<void> onDeleteSelectedPressed(BuildContext context) async {
  final viewModel = context.read<MyRatingsViewModel>();
  final count = viewModel.selectedRatingIds.length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('선택한 평점 $count개를 삭제할까요?'),
      content: const Text('삭제한 평점은 복구할 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  // 여기서 Dialog는 이미 닫혔다. 삭제 요청은 이제부터 화면의 ViewModel이 이어받는다.
  if (confirmed != true || !context.mounted) return;

  await viewModel.deleteSelectedRatings();
  if (!context.mounted) return;
  // 일부만 실패하면 성공한 항목만 목록에서 사라지고, 실패 개수를 알린다.
  _showSnackBar(
    context,
    viewModel.takeSnackbarMessage() ?? '선택한 평점 $count개를 삭제했습니다.',
  );
}

void _showSnackBar(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

/// 단건 삭제 확인 Dialog. 삭제 요청 중에는 버튼이 로딩 상태가 되고 Dialog가 닫히지 않는다.
class _DeleteRatingDialog extends StatefulWidget {
  const _DeleteRatingDialog({required this.title, required this.onConfirm});

  final String title;
  final Future<void> Function() onConfirm;

  @override
  State<_DeleteRatingDialog> createState() => _DeleteRatingDialogState();
}

class _DeleteRatingDialogState extends State<_DeleteRatingDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: Text(widget.title),
        content: const Text('삭제한 평점은 복구할 수 없습니다.'),
        actions: [
          MovieLogButton(
            label: '취소',
            // "취소"는 onConfirm을 부르지 않는다 → 삭제 요청 없음.
            onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          ),
          MovieLogButton(
            label: '삭제',
            isLoading: _isDeleting,
            onPressed: _isDeleting ? null : _onConfirm,
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    setState(() => _isDeleting = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      // 실패하면 Dialog를 닫지 않고 다시 시도할 수 있게 둔다.
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('삭제하지 못했습니다. ${submitErrorMessage(error)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class _RatingsLoading extends StatelessWidget {
  const _RatingsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('평점을 불러오는 중이에요', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _RatingsList extends StatelessWidget {
  const _RatingsList({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ratings = viewModel.ratings;
    final isEditMode = viewModel.isEditMode;

    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _ListHeader(viewModel: viewModel),
          // 일부 영화의 TMDB 정보를 못 받았을 때만 보이는 안내.
          if (viewModel.message case final message?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(message, style: AppTextStyles.bodySmall),
            ),
          for (final entry in ratings)
            MyRatingTile(
              key: ValueKey(entry.rating.ratingId),
              entry: entry,
              selected: isEditMode
                  ? viewModel.selectedRatingIds.contains(entry.rating.ratingId)
                  : null,
              // 편집 모드에서는 카드 탭 = 선택 토글, 기본 모드에서는 상세로 이동.
              onTap: isEditMode
                  ? () => viewModel.toggleSelected(entry.rating.ratingId)
                  : () => context.push(
                      '/movies/${entry.rating.movieId}',
                      extra: entry.movie,
                    ),
              onEdit: () => onEditPressed(context, entry.rating),
              onDelete: () => onDeletePressed(context, entry.rating),
            ),
        ],
      ),
    );
  }
}

/// 목록 상단 한 줄: 왼쪽 개수(편집 모드면 선택 수), 오른쪽 "편집"/"취소".
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.viewModel});

  final MyRatingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isEditMode = viewModel.isEditMode;
    final text = isEditMode
        ? '${viewModel.selectedRatingIds.length}개 선택'
        : '이번 로그인에서 등록한 평점 ${viewModel.ratings.length}개';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.violetLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isEditMode ? Icons.check_box_outlined : Icons.info_outline,
            size: 18,
            color: AppColors.violet,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.black),
            ),
          ),
          TextButton(
            onPressed: isEditMode
                ? viewModel.exitEditMode
                : viewModel.enterEditMode,
            child: Text(isEditMode ? '취소' : '편집'),
          ),
        ],
      ),
    );
  }
}
