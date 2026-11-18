import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_text_styles.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/favorite_button.dart';
import '../widgets/movie_average_rating.dart';
import '../widgets/movielog_button.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_movie_card.dart';
import '../widgets/tmdb_poster_image.dart';
import 'movie_detail_loader.dart';

/// 영화 상세 화면.
///
/// 5주차: TMDB DTO로 포스터·제목·줄거리를 그린다. ([MovieDetailLoader]가 DTO를 준비한다)
/// 7주차: 평점 Dialog에서 별점·코멘트를 받아 **등록만** 한다.
/// 8주차: `POST /v8/ratings`(토큰 기반)로 바꿨다. 등록 result(Rating 객체)로 "내 평점" 영역을 바로 갱신한다.
/// 9주차: 3주차의 mock 즐겨찾기 버튼을 없애고, 제목 오른쪽의 [FavoriteButton]이 서버(`/v8/favorites`)와 통신한다.
/// Challenge: 평점 Dialog에 "즐겨찾기에도 추가" 체크박스를 더해 `POST /v8/movie-records`로 한 번에 저장한다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 화면이 처음 만들어질 때 서버의 즐겨찾기 여부를 한 번 조회한다. build()에서는 조회하지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoriteDetailViewModel>().load();
    });
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context)
      // 연타했을 때 이전 안내가 쌓이지 않도록 먼저 지운다.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// 평점 남기기 → Dialog가 저장까지 마치고 true를 반환한 뒤에만 성공 Snackbar를 띄운다.
  ///
  /// 실패는 오류 code로 나눈다.
  /// - `COMMON400`·네트워크 실패: Dialog를 열어 둔 채 Dialog 안에 이유를 보여 준다. 별점·코멘트는 유지된다.
  /// - `RATING409_1`·`FAVORITE409_1`·`MEMBER404_1`: Dialog를 닫고 Snackbar로 어떤 오류인지 안내한다.
  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final favorite = context.read<FavoriteDetailViewModel>();
    // 즐겨찾기 여부를 서버에서 확인했고, 아직 즐겨찾기하지 않은 영화일 때만 체크박스를 보여 준다.
    final alreadyFavorite = favorite.isFavorite || !favorite.hasLoadedStatus;

    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
      builder: (_) => RatingDialog(
        showAddToFavorite: !alreadyFavorite,
        onSubmit: (score, comment, addToFavorites) async {
          await viewModel.saveRating(
            score: score,
            comment: comment,
            addToFavorites: addToFavorites,
            alreadyFavorite: alreadyFavorite,
          );
          if (viewModel.submitStatus == SubmitStatus.success) return;
          final message = viewModel.submitMessage ?? '저장에 실패했습니다.';
          // 다시 눌러도 소용없는 오류는 Dialog를 닫고 Snackbar로 알린다.
          const closeCodes = {'RATING409_1', 'FAVORITE409_1', 'MEMBER404_1'};
          if (closeCodes.contains(viewModel.submitErrorCode)) {
            throw RatingSubmitClosed(message);
          }
          throw StateError(message);
        },
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계다. await 뒤에는 mounted를 다시 확인한다.
    if (!mounted) return;
    if (result is RatingSubmitClosed) {
      _showSnackBar(result.message);
      // FAVORITE409_1이면 서버 기준으로 북마크 상태가 달랐다는 뜻이므로 다시 맞춘다.
      unawaited(favorite.load());
      return;
    }
    if (result != true) return;
    _showSnackBar('평점을 저장했습니다.');
    // 평점과 함께 즐겨찾기를 저장했을 수 있다. 북마크 상태를 서버 값으로 다시 맞춘다.
    unawaited(favorite.load());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;

    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 상세',
        titleStyle: AppTextStyles.titleMedium,
        centerTitle: true,
        onBack: () => goBackFromDetail(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MovieDetailHeader(movie: movie),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('줄거리', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            _Overview(overview: movie.overview),
            const SizedBox(height: 24),
            _MyRatingSection(
              registeredScore: viewModel.myRating?.score,
              onRatePressed: _openRatingDialog,
            ),
          ],
        ),
      ),
    );
  }
}

/// 줄거리. 번역된 줄거리가 없으면(빈 문자열) 안내 문구를 가운데에 보여 준다.
class _Overview extends StatelessWidget {
  const _Overview({required this.overview});

  final String overview;

  @override
  Widget build(BuildContext context) {
    if (overview.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '줄거리 정보가 없어요.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
      );
    }
    return Text(overview, style: AppTextStyles.bodyMedium);
  }
}

class _MovieDetailHeader extends StatelessWidget {
  const _MovieDetailHeader({required this.movie});

  final TmdbMovieDto movie;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 220,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TmdbPosterImage(posterPath: movie.posterPath),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 제목·정보 텍스트 오른쪽에 즐겨찾기 버튼. 왼쪽 빈 칸은 제목이 가운데로 보이게 맞추는 용도다.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 62),
            Expanded(
              child: Column(
                children: [
                  Text(
                    movie.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  if (releaseYearOf(movie) case final year?)
                    Text('$year년 개봉', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const FavoriteButton(),
          ],
        ),
        const SizedBox(height: 12),
        // TMDB 평점은 10점 만점이라 별 5개에 맞춰 반으로 나눠 표시한다. 평가가 없으면 0이 온다.
        MovieAverageRating(
          rating: movie.voteAverage > 0 ? movie.voteAverage / 2 : null,
        ),
        const SizedBox(height: 4),
        Text(
          'TMDB 평점 ${movie.voteAverage.toStringAsFixed(1)} / 10 · movieId ${movie.id}',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

/// 내 평점 영역과 '평점 남기기' 버튼.
///
/// 이번 세션에서 이미 등록했으면 점수를 보여 주고, 같은 영화에 다시 POST하지 않는다. (서버도 RATING409_1로 막는다)
class _MyRatingSection extends StatelessWidget {
  const _MyRatingSection({
    required this.registeredScore,
    required this.onRatePressed,
  });

  final int? registeredScore;
  final VoidCallback onRatePressed;

  @override
  Widget build(BuildContext context) {
    final score = registeredScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('내 평점', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        if (score != null)
          MovieAverageRating(rating: score.toDouble(), itemSize: 20)
        else
          const Text('아직 평점을 남기지 않았어요', style: AppTextStyles.bodySmall),
        const SizedBox(height: 16),
        MovieLogButton(
          label: score == null ? '평점 남기기' : '등록 완료 · 수정은 마이페이지에서',
          width: double.infinity,
          onPressed: score == null ? onRatePressed : null,
        ),
      ],
    );
  }
}
