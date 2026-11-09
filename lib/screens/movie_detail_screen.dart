import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
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
/// 8주차: `POST /v7/ratings`(토큰 기반)로 바꿨다. 등록 result(Rating 객체)로 "내 평점" 영역을 바로 갱신한다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 즐겨찾기는 8주차에 MovieLog API로 연결한다. 지금은 화면 안 상태로만 다룬다.
  bool _isFavorite = false;

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

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    _showSnackBar(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
  }

  /// 평점 남기기 → Dialog가 저장까지 마치고 true를 반환한 뒤에만 성공 Snackbar를 띄운다.
  ///
  /// 실패(400/404/409)는 Dialog 안에 서버 message로 보여 주고 Dialog는 열린 채 입력을 유지한다.
  /// movieId는 이 화면의 ViewModel이 이미 갖고 있어 onSubmit 밖으로 따로 넘기지 않는다.
  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막는다.
      builder: (_) => RatingDialog(
        onSubmit: (score, comment) async {
          await viewModel.createRating(score: score, comment: comment);
          if (viewModel.submitStatus != SubmitStatus.success) {
            throw StateError(viewModel.submitMessage ?? '저장에 실패했습니다.');
          }
        },
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계다. await 뒤에는 mounted를 다시 확인한다.
    if (!mounted || saved != true) return;
    _showSnackBar('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
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
        actions: [
          IconButton(
            tooltip: _isFavorite ? '즐겨찾기 삭제' : '즐겨찾기 추가',
            icon: Icon(
              _isFavorite ? Icons.bookmark : Icons.bookmark_border,
              color: AppColors.violet,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
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
        Text(
          movie.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge,
        ),
        const SizedBox(height: 4),
        if (releaseYearOf(movie) case final year?)
          Text('$year년 개봉', style: AppTextStyles.bodySmall),
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
