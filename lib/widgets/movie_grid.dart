import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import 'tmdb_movie_card.dart';

/// 목록 화면과 Loading Skeleton이 같은 칸 모양을 쓰도록 공유하는 Grid 설정.
const movieGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 16,
  // 가로 / 세로. 포스터(2:3)에 글자 두 줄이 더해지므로 0.67보다 작게 잡는다.
  childAspectRatio: 0.6,
);

const movieGridPadding = EdgeInsets.fromLTRB(16, 0, 16, 24);

/// 영화 목록의 Success 화면.
///
/// 데이터를 어떻게 가져왔는지(Mock인지 TMDB인지)는 알지 못하고,
/// 받은 목록을 그리는 일만 한다.
class MovieGrid extends StatelessWidget {
  const MovieGrid({
    super.key,
    required this.movies,
    required this.onMovieTap,
    this.genreNames = const {},
    this.preferredGenreIds = const [],
    this.onRefresh,
    this.refreshIndicatorKey,
  });

  final List<TmdbMovieDto> movies;
  final ValueChanged<TmdbMovieDto> onMovieTap;
  final Map<int, String> genreNames;

  /// 선택된 장르. 카드 아래 장르 이름을 고를 때 먼저 쓴다.
  final List<int> preferredGenreIds;

  /// 당겨서 새로고침. (Challenge) null이면 RefreshIndicator를 달지 않는다.
  final Future<void> Function()? onRefresh;

  /// 재시도 Dialog에서 새로고침을 코드로 다시 띄울 때 쓴다.
  final GlobalKey<RefreshIndicatorState>? refreshIndicatorKey;

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
        return TmdbMovieCard(
          // 같은 자리에 다른 영화가 와도 이전 이미지가 남지 않도록 TMDB id로 구분한다.
          key: ValueKey(movie.id),
          movie: movie,
          genreNames: genreNames,
          preferredGenreIds: preferredGenreIds,
          onTap: () => onMovieTap(movie),
        );
      },
    );

    if (onRefresh == null) return grid;

    // RefreshIndicator는 스크롤되는 Widget을 바로 감싸야 동작한다.
    return RefreshIndicator(
      key: refreshIndicatorKey,
      onRefresh: onRefresh!,
      child: grid,
    );
  }
}
