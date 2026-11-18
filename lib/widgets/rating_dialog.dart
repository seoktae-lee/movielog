import 'package:flutter/material.dart';

import '../data/models/rating_request.dart';
import '../data/services/rating_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';
import 'movielog_button.dart';

/// [RatingDialog]의 onSubmit이 던지면 Dialog를 **닫고**, 호출부가 Snackbar로 어떤 오류인지 안내하게 한다. (9주차)
///
/// 입력을 고쳐 다시 시도할 수 있는 오류(`COMMON400`, 네트워크 실패)는 이 예외가 아니라 일반 예외를 던져
/// Dialog를 열어 둔다. 이 예외는 다시 눌러도 소용없는 오류(`RATING409_1`·`FAVORITE409_1`·`MEMBER404_1`)용이다.
class RatingSubmitClosed implements Exception {
  const RatingSubmitClosed(this.message);

  final String message;

  @override
  String toString() => 'RatingSubmitClosed($message)';
}

/// 별점과 코멘트를 받아 저장까지 하는 커스텀 Dialog. (등록·수정 공용)
///
/// 저장 로직은 [onSubmit] 콜백으로 받아 Dialog 안에서 실행한다.
/// - 확인 → onSubmit이 예외 없이 끝나면 `true`를 반환하며 닫힌다.
/// - onSubmit이 예외를 던지면 닫히지 않고 오류 문구를 보여 준다. 입력한 별점·코멘트는 그대로 남는다.
/// - onSubmit이 [RatingSubmitClosed]를 던지면 그 객체를 반환하며 닫힌다. (호출부가 Snackbar로 안내)
/// - 취소 → onSubmit을 호출하지 않고 `false`. (API 요청 없음)
///
/// 9주차 Challenge: [showAddToFavorite]가 true면 "즐겨찾기에도 추가" 체크박스를 보여 주고,
/// 체크 여부를 onSubmit의 세 번째 인자로 넘긴다. 같은 Dialog를 평점 수정에서도 쓰므로 기본값은 false(숨김)이고,
/// 이때 `addToFavorites`는 항상 false다.
///
/// 저장 중에는 [PopScope]로 뒤로가기를 막는다. 바깥 탭은 호출부의 `barrierDismissible: false`가 막는다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    this.initialScore = 0,
    this.initialComment,
    this.showAddToFavorite = false,
    required this.onSubmit,
  });

  /// 수정이면 기존 점수, 등록이면 0(아직 고르지 않음).
  final int initialScore;

  /// 수정이면 기존 코멘트. null이면 TextField가 빈 칸으로 시작한다.
  final String? initialComment;

  /// 상세에서 "아직 즐겨찾기하지 않은 영화"에 평점을 남길 때만 true.
  final bool showAddToFavorite;

  final Future<void> Function(int score, String? comment, bool addToFavorites)
  onSubmit;

  static const maxCommentLength = 500;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int _score = widget.initialScore;

  // build 안에서 만들면 별점을 고를 때(setState)마다 새로 만들어져 입력하던 코멘트가 사라진다.
  // State가 살아 있는 동안 한 번만 만들고 dispose에서 정리한다.
  late final _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );
  bool _isSubmitting = false;
  bool _addToFavorites = false;
  String? _errorText;

  bool get _isEdit => widget.initialScore > 0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasScore = _score > 0;

    return PopScope(
      // 저장 중에는 시스템 뒤로가기·스와이프로 닫히지 않는다.
      canPop: !_isSubmitting,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              // 화면 전체 높이가 아니라 내용물 높이만큼만 차지한다.
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEdit ? '평점을 수정해 주세요' : '영화는 어떠셨나요?',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 24),
                MovieRatingInput(
                  rating: _score.toDouble(),
                  enabled: !_isSubmitting,
                  onChanged: (value) =>
                      setState(() => _score = validateServerScore(value)),
                ),
                const SizedBox(height: 12),
                Text(
                  hasScore ? '$_score점' : '별을 눌러 평점을 골라 주세요',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: hasScore ? AppColors.violet : AppColors.gray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  maxLength: RatingDialog.maxCommentLength,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    hintText: '코멘트를 남겨보세요 (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (widget.showAddToFavorite)
                  CheckboxListTile(
                    key: const ValueKey('add-to-favorite'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.violet,
                    title: const Text('즐겨찾기에도 추가'),
                    value: _addToFavorites,
                    onChanged: _isSubmitting
                        ? null
                        : (value) =>
                              setState(() => _addToFavorites = value ?? false),
                  ),
                if (_errorText case final error?) ...[
                  const SizedBox(height: 4),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MovieLogButton(
                        label: '취소',
                        width: double.infinity,
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MovieLogButton(
                        label: '확인',
                        width: double.infinity,
                        // 저장 중에는 회색 + 인디케이터. 연속 탭으로 요청이 두 번 가지 않는다.
                        isLoading: _isSubmitting,
                        // 별점을 고르지 않았으면 코멘트가 있어도 누를 수 없다.
                        onPressed: hasScore && !_isSubmitting
                            ? _onConfirm
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    final trimmed = _commentController.text.trim();
    if (trimmed.length > RatingDialog.maxCommentLength) {
      setState(() => _errorText = '코멘트는 500자 이하로 입력해 주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // 빈 문자열은 null로 바꿔 보낸다.
      await widget.onSubmit(
        _score,
        trimmed.isEmpty ? null : trimmed,
        widget.showAddToFavorite && _addToFavorites,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on RatingSubmitClosed catch (closed) {
      if (!mounted) return;
      Navigator.pop(context, closed);
    } catch (error) {
      if (!mounted) return;
      // 실패해도 로딩을 반드시 풀어야 다시 시도할 수 있다. 입력값은 건드리지 않는다.
      setState(() {
        _isSubmitting = false;
        _errorText = submitErrorMessage(error);
      });
    }
  }
}
