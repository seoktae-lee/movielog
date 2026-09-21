import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/mock_movies.dart';
import 'models/movie.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/movie_average_rating.dart';
import 'widgets/rating_dialog.dart';

/// 3주차 영화 상세 화면.
///
/// Extra로 Movie 객체를 받지 않고 Path Parameter의 ID로 Mock Data를 다시 찾는다.
/// 그래야 URL로 바로 들어오거나 앱을 다시 켰을 때도 같은 화면을 그릴 수 있다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  /// `/movies/:movieId`에서 읽은 값. 숫자가 아니면 Router가 null을 넘긴다.
  final int? movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  // 즐겨찾기와 내 평점은 8주차에 API로 연결한다. 지금은 화면 안 상태로만 다룬다.
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

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    ScaffoldMessenger.of(context)
      // 연타했을 때 이전 안내가 쌓이지 않도록 먼저 지운다.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openRatingDialog() async {
    // Dialog 안에서 Navigator.pop(context, rating)으로 넘긴 값이 여기로 돌아온다.
    final rating = await showDialog<double>(
      context: context,
      builder: (dialogContext) => RatingDialog(initialRating: _myRating ?? 0),
    );

    if (rating == null || !mounted) return;

    setState(() {
      _myRating = rating;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${rating.toStringAsFixed(1)}점을 남겼습니다.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final movie = findMovieById(widget.movieId);

    if (movie == null) {
      return _MovieNotFound(onBack: _goBack);
    }

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
            Text(
              '${movie.year}년 개봉한 ${movie.genre} 영화 「${movie.title}」의 줄거리입니다. '
              '실제 줄거리와 상세 정보는 8주차에 서버 API와 연결하면 이 자리에 표시됩니다.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            _MyRatingSection(
              myRating: _myRating,
              onRatePressed: _openRatingDialog,
            ),
          ],
        ),
      ),
    );
  }
}

/// 포스터, 제목, 장르·연도, 평균 평점.
class _MovieDetailHeader extends StatelessWidget {
  const _MovieDetailHeader({required this.movie});

  final Movie movie;

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
                child: Image.asset(movie.posterAsset, fit: BoxFit.cover),
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
        Text('${movie.genre} · ${movie.year}', style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),
        // 워크북 요구사항: 평균 평점을 RatingBarIndicator로 읽기 전용 표시(별빛 아래 우리 = 4.5)
        MovieAverageRating(rating: movie.rating),
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

/// 잘못된 ID로 들어왔을 때 보여 주는 화면.
class _MovieNotFound extends StatelessWidget {
  const _MovieNotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: '영화 상세', onBack: onBack),
      body: const Center(
        child: Text('영화를 찾을 수 없어요', style: AppTextStyles.bodyMedium),
      ),
    );
  }
}
