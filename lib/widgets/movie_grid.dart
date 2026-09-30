import 'package:flutter/material.dart';

import '../models/movie.dart';
import 'movie_card.dart';

/// 목록 화면과 Loading Skeleton이 같은 칸 모양을 쓰도록 공유하는 Grid 설정.
const movieGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 16,
  // 가로 / 세로. 포스터(2:3)에 글자 두 줄이 더해지므로 0.67보다 작게 잡는다.
  childAspectRatio: 0.6,
);

const movieGridPadding = EdgeInsets.fromLTRB(16, 0, 16, 24);

/// 영화 목록의 Success 화면. 3주차 [MovieCard]를 그대로 재사용한다.
///
/// 데이터를 어떻게 가져왔는지(Mock인지 API인지)는 알지 못하고,
/// 받은 목록을 그리는 일만 한다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    required this.onMovieTap,
    this.onRefresh,
  });

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  /// 당겨서 새로고침. (Challenge) null이면 RefreshIndicator를 달지 않는다.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final grid = GridView.builder(
      padding: movieGridPadding,
      // 목록이 짧아도 당겨서 새로고침할 수 있도록 항상 스크롤을 허용한다.
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: movieGridDelegate,
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(movie: movie, onTap: () => onMovieTap(movie));
      },
    );

    if (onRefresh == null) return grid;

    // RefreshIndicator는 스크롤되는 Widget을 바로 감싸야 동작한다.
    return RefreshIndicator(onRefresh: onRefresh!, child: grid);
  }
}
