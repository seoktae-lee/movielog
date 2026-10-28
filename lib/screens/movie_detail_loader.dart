import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/common_app_bar.dart';
import 'movie_detail_screen.dart';

/// 영화 상세 화면의 시작점. 화면에 그릴 [TmdbMovieDto]를 확보한 뒤 [MovieDetailViewModel]을 만든다.
///
/// - 목록·홈에서 push로 오면 `state.extra`로 받은 DTO를 그대로 쓴다. (TMDB 재요청 없음)
/// - URL로 바로 들어오면(Deep Link) extra가 없으므로 `GET /movie/{movie_id}`로 다시 조회한다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({
    super.key,
    required this.movieId,
    this.initialMovie,
  });

  final int movieId;
  final TmdbMovieDto? initialMovie;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  // build마다 새 Future를 만들면 리빌드 때마다 TMDB를 다시 부른다. State에 한 번만 만든다.
  late Future<TmdbMovieDto> _movieFuture = _fetch();

  Future<TmdbMovieDto> _fetch() => widget.initialMovie != null
      ? Future.value(widget.initialMovie!)
      : context.read<TmdbMovieService>().fetchMovieDetail(widget.movieId);

  void _retry() => setState(() => _movieFuture = _fetch());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TmdbMovieDto>(
      future: _movieFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DetailScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          final error = snapshot.error;
          final notFound =
              error is DioException && error.response?.statusCode == 404;
          return _DetailScaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notFound ? '영화를 찾을 수 없어요' : '영화를 불러오지 못했습니다.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (!notFound) ...[
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('다시 시도')),
                  ],
                ],
              ),
            ),
          );
        }
        return ChangeNotifierProvider<MovieDetailViewModel>(
          create: (context) => MovieDetailViewModel(
            context.read<RatingApiService>(),
            // 6주차 고정 memberId 1이 아니라 회원가입 결과로 저장한 학습용 ID.
            context.read<LearningMemberSession>().memberId,
            snapshot.data!,
          ),
          child: const MovieDetailScreen(),
        );
      },
    );
  }
}

/// `/movies/abc`, `/movies/0`처럼 영화 ID가 올바르지 않을 때.
class MovieDetailInvalidId extends StatelessWidget {
  const MovieDetailInvalidId({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DetailScaffold(
      body: Center(
        child: Text('영화 ID가 올바르지 않습니다.', style: AppTextStyles.bodyMedium),
      ),
    );
  }
}

/// 로딩·오류 화면도 상세 화면과 같은 AppBar(뒤로가기)를 쓴다.
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 상세',
        onBack: () => goBackFromDetail(context),
      ),
      body: body,
    );
  }
}

/// push로 들어왔으면 pop, URL로 바로 들어와 Stack이 비어 있으면 홈으로 보낸다.
void goBackFromDetail(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}
