import 'package:flutter/material.dart';

import '../data/models/tmdb_movie_dto.dart';
import 'movie_card.dart';
import 'tmdb_poster_image.dart';

/// TMDB 영화 DTO를 [MovieCard]로 그린다.
///
/// DTO에서 화면용 값(연도·장르 이름·평점 배지)을 뽑는 규칙을 한곳에 모았다.
class TmdbMovieCard extends StatelessWidget {
  const TmdbMovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.genreNames = const {},
    this.width,
  });

  final TmdbMovieDto movie;
  final VoidCallback onTap;

  /// 장르 ID → 이름. 모르면 장르를 빼고 연도만 표시한다.
  final Map<int, String> genreNames;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return MovieCard(
      poster: TmdbPosterImage(posterPath: movie.posterPath),
      title: movie.title,
      subtitle: movieSubtitle(movie, genreNames),
      // 평가가 한 건도 없으면 0.0이 온다. 0.0을 평점처럼 보이지 않게 배지를 숨긴다.
      rating: movie.voteAverage > 0 ? movie.voteAverage : null,
      onTap: onTap,
      width: width,
    );
  }
}

/// `2025-07-01` → 2025. 값이 없거나 형식이 다르면 null(연도를 표시하지 않음).
int? releaseYearOf(TmdbMovieDto movie) {
  final date = movie.releaseDate;
  if (date == null || date.length < 4) return null;
  return int.tryParse(date.substring(0, 4));
}

/// "액션 · 2025". 장르·연도 중 없는 값은 빼고 잇는다.
String movieSubtitle(TmdbMovieDto movie, Map<int, String> genreNames) {
  final genre = movie.genreIds
      .map((id) => genreNames[id])
      .whereType<String>()
      .firstOrNull;
  final year = releaseYearOf(movie);
  return [?genre, if (year != null) '$year'].join(' · ');
}
