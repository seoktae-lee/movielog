// TMDB JSON → DTO 변환(snake_case·null·num)을 확인하는 Unit 테스트.

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/tmdb_genre_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/models/tmdb_movie_page.dart';
import 'package:movielog/widgets/tmdb_movie_card.dart';

void main() {
  test('snake_case Key를 lowerCamelCase 필드로 연결하고 num을 double로 바꾼다', () {
    final movie = TmdbMovieDto.fromJson({
      'id': 550,
      'title': '파이트 클럽',
      'overview': '줄거리',
      'poster_path': '/poster.jpg',
      'backdrop_path': '/backdrop.jpg',
      'release_date': '1999-10-15',
      'genre_ids': [18, 53],
      // 정수로 와도 double 필드에 들어가야 한다.
      'vote_average': 8,
      'popularity': 120.5,
    });

    expect(movie.id, 550);
    expect(movie.posterPath, '/poster.jpg');
    expect(movie.backdropPath, '/backdrop.jpg');
    expect(movie.releaseDate, '1999-10-15');
    expect(movie.genreIds, [18, 53]);
    expect(movie.voteAverage, 8.0);
    expect(movie.popularity, 120.5);
  });

  test('값이 null이거나 빠져 있어도 기본값으로 변환된다', () {
    final movie = TmdbMovieDto.fromJson({
      'id': 1,
      'title': null,
      'poster_path': null,
      'release_date': null,
    });

    expect(movie.title, '제목 없음');
    expect(movie.overview, '');
    expect(movie.posterPath, isNull);
    expect(movie.releaseDate, isNull);
    expect(movie.genreIds, isEmpty);
    expect(movie.voteAverage, 0);
  });

  test('상세 응답의 genres 배열에서도 장르 ID를 읽는다', () {
    final movie = TmdbMovieDto.fromJson({
      'id': 1,
      'title': '상세',
      'genres': [
        {'id': 28, 'name': '액션'},
        {'id': 12, 'name': '모험'},
      ],
    });

    expect(movie.genreIds, [28, 12]);
  });

  test('페이지 응답을 영화 배열과 metadata로 나눈다', () {
    final page = TmdbMoviePageDto.fromJson({
      'page': 2,
      'results': [
        {'id': 1, 'title': 'A'},
        {'id': 2, 'title': 'B'},
      ],
      'total_pages': 7,
      'total_results': 130,
    });

    expect(page.page, 2);
    expect(page.results.map((movie) => movie.id), [1, 2]);
    expect(page.totalPages, 7);
    expect(page.totalResults, 130);
  });

  test('장르 응답을 id와 name으로 변환한다', () {
    final genre = TmdbGenreDto.fromJson({'id': 28, 'name': '액션'});

    expect(genre.id, 28);
    expect(genre.name, '액션');
  });

  test('카드 아래 한 줄은 선택한 장르를 먼저, 없는 값은 빼고 만든다', () {
    const names = {878: 'SF', 28: '액션'};
    final movie = TmdbMovieDto.fromJson({
      'id': 1,
      'title': '스파이더맨',
      'genre_ids': [878, 28],
      'release_date': '2026-07-29',
    });
    final noDate = TmdbMovieDto.fromJson({
      'id': 2,
      'title': '미정',
      'genre_ids': <int>[],
      'release_date': '',
    });

    expect(movieSubtitle(movie, names), 'SF · 2026');
    expect(movieSubtitle(movie, names, preferredGenreIds: [28]), '액션 · 2026');
    expect(movieSubtitle(noDate, names), '');
  });
}
