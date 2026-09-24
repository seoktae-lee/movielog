import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_grid.dart';

/// 영화 목록의 Loading 화면.
///
/// "빈 화면 + 동그라미" 대신 실제 카드가 놓일 자리를 회색 상자로 먼저 보여 주는
/// Skeleton UI다. (Challenge) 화면이 어떻게 채워질지 미리 알 수 있어 체감 대기가 짧다.
class MovieListLoading extends StatefulWidget {
  const MovieListLoading({super.key, this.itemCount = 4});

  /// 미리 그려 둘 자리 개수.
  final int itemCount;

  @override
  State<MovieListLoading> createState() => _MovieListLoadingState();
}

class _MovieListLoadingState extends State<MovieListLoading>
    with SingleTickerProviderStateMixin {
  // 회색 상자를 천천히 밝아졌다 어두워지게 해서 "멈춘 화면"으로 보이지 않게 한다.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    // 화면이 사라지면 애니메이션도 멈춰야 한다. 안 그러면 계속 돌면서 메모리를 잡는다.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('영화를 불러오는 중이에요', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: FadeTransition(
            opacity: _opacity,
            child: GridView.builder(
              padding: movieGridPadding,
              // 아직 내용이 없으므로 스크롤은 막아 둔다.
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: movieGridDelegate,
              itemCount: widget.itemCount,
              itemBuilder: (context, index) => const _MovieCardSkeleton(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 영화 카드 한 장이 놓일 자리를 대신하는 회색 상자.
class _MovieCardSkeleton extends StatelessWidget {
  const _MovieCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 포스터 자리
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.gray.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SkeletonLine(widthFactor: 0.8, height: 14),
        const SizedBox(height: 6),
        _SkeletonLine(widthFactor: 0.5, height: 12),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.gray.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
