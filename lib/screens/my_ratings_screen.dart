import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/my_rating_tile.dart';

/// 마이페이지 → "내가 등록한 평점" 자식 화면.
///
/// root Navigator 위에 push되므로 하단 NavigationBar가 없다.
/// 화면 이름은 "내가 등록한 평점"이지만, 로그인 전이라 학습용 memberId 1의 공개 평점을 보여 준다.
/// 그래서 수정·삭제 버튼을 두지 않는다.
class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('내가 등록한 평점'),
        centerTitle: true,
      ),
      // bottomNavigationBar를 전달하지 않는다.
      body: Consumer<MyRatingsViewModel>(
        builder: (context, viewModel, child) {
          return switch (viewModel.status) {
            MyRatingsLoadStatus.idle ||
            MyRatingsLoadStatus.loading => const _RatingsLoading(),
            MyRatingsLoadStatus.empty => MovieListEmpty(
              message: '아직 등록한 평점이 없습니다.',
              description: 'memberId ${viewModel.memberId}의 평점 기록이 비어 있어요.',
            ),
            MyRatingsLoadStatus.error => MovieListError(
              message: viewModel.message ?? '평점을 불러오지 못했습니다.',
              description: 'memberId ${viewModel.memberId} 조회에 실패했어요.',
              onRetry: viewModel.load,
            ),
            MyRatingsLoadStatus.success => _RatingsList(viewModel: viewModel),
          };
        },
      ),
    );
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

    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _SampleDataNotice(
            memberId: viewModel.memberId,
            count: ratings.length,
          ),
          // 일부 영화의 TMDB 정보를 못 받았을 때만 보이는 안내.
          if (viewModel.message case final message?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(message, style: AppTextStyles.bodySmall),
            ),
          for (final entry in ratings)
            MyRatingTile(
              entry: entry,
              // TMDB id로 상세에 간다. 받은 영화가 있으면 extra로 넘겨 다시 부르지 않는다.
              onTap: () => context.push(
                '/movies/${entry.rating.movieId}',
                extra: entry.movie,
              ),
            ),
        ],
      ),
    );
  }
}

/// 이 목록이 로그인한 "나"가 아니라 학습용 회원의 데이터라는 안내.
class _SampleDataNotice extends StatelessWidget {
  const _SampleDataNotice({required this.memberId, required this.count});

  final int memberId;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.violetLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.violet),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '학습용 memberId $memberId의 공개 평점 $count개',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }
}
