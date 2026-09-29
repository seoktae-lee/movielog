import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/create_rating_request.dart';
import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_average_rating.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/tmdb_movie_card.dart';
import '../widgets/tmdb_poster_image.dart';

/// 5주차 영화 상세 화면.
///
/// 홈·목록에서 넘겨받은 TMDB DTO를 그리고, URL로 바로 들어오면
/// [MovieDetailViewModel]이 `movieId`로 TMDB 상세 API를 호출한다.
/// 평점 Dialog에는 목록 index가 아니라 `TmdbMovieDto.id`를 넘긴다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 즐겨찾기와 내 평점은 이후 주차에 MovieLog API로 연결한다. 지금은 화면 안 상태로만 다룬다.
  bool _isFavorite = false;
  double? _myRating;

  /// push로 들어왔으면 pop, URL로 바로 들어와 Stack이 비어 있으면 홈으로 보낸다.
  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context)
      // 연타했을 때 이전 안내가 쌓이지 않도록 먼저 지운다.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    _showSnackBar(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
  }

  Future<void> _openRatingDialog(TmdbMovieDto movie) async {
    // Dialog에 TMDB id를 넘기고, 확인을 누르면 평점 요청 Body가 그대로 돌아온다.
    final request = await showDialog<CreateRatingRequest>(
      context: context,
      builder: (dialogContext) =>
          RatingDialog(movieId: movie.id, initialRating: _myRating ?? 0),
    );

    if (request == null || !mounted) return;

    // 실제 저장 API는 이후 주차에 연결한다. 지금은 보낼 Body가 맞는지 로그로 확인한다.
    debugPrint('[평점 요청 준비] ${request.toJson()}');

    setState(() {
      _myRating = request.score;
    });
    _showSnackBar('${request.score.toStringAsFixed(1)}점을 남겼습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();

    switch (viewModel.status) {
      case MovieDetailLoadStatus.idle:
      case MovieDetailLoadStatus.loading:
        return _DetailScaffold(
          onBack: _goBack,
          body: const Center(child: CircularProgressIndicator()),
        );
      case MovieDetailLoadStatus.notFound:
        return _DetailScaffold(
          onBack: _goBack,
          body: const Center(
            child: Text('영화를 찾을 수 없어요', style: AppTextStyles.bodyMedium),
          ),
        );
      case MovieDetailLoadStatus.error:
        return _DetailScaffold(
          onBack: _goBack,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  viewModel.message ?? '영화 정보를 불러오지 못했어요.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.read<MovieDetailViewModel>().load(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        );
      case MovieDetailLoadStatus.success:
        break;
    }

    final movie = viewModel.movie!;

    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 상세',
        titleStyle: AppTextStyles.titleMedium,
        centerTitle: true,
        onBack: _goBack,
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
              myRating: _myRating,
              onRatePressed: () => _openRatingDialog(movie),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로딩·오류·없음 화면이 같은 AppBar를 쓰도록 묶었다.
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.onBack, required this.body});

  final VoidCallback onBack;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: '영화 상세', onBack: onBack),
      body: body,
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

/// 내가 남긴 평점과 '평점 남기기' 버튼.
class _MyRatingSection extends StatelessWidget {
  const _MyRatingSection({required this.myRating, required this.onRatePressed});

  final double? myRating;
  final VoidCallback onRatePressed;

  @override
  Widget build(BuildContext context) {
    final hasRating = myRating != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('내 평점', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        if (hasRating)
          MovieAverageRating(rating: myRating, itemSize: 20)
        else
          const Text('아직 평점을 남기지 않았어요', style: AppTextStyles.bodySmall),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onRatePressed,
            icon: const Icon(Icons.star_outline),
            label: Text(hasRating ? '평점 수정하기' : '평점 남기기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: AppColors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
