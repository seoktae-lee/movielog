import '../models/movie.dart';

/// 3주차에서 홈·목록·상세 화면이 공유하는 Mock 영화 데이터.
///
/// 실제 서버와 연결하지 않으며, 세 화면이 서로 다른 하드코딩 값을 쓰지 않도록
/// 반드시 이 목록을 통해서만 영화를 읽는다.
const List<Movie> movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genre: '드라마',
    year: 2024,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    rating: 4.5,
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genre: 'SF',
    year: 2024,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    rating: 4.2,
  ),
  Movie(
    id: 3,
    title: '심연을 걷는 자',
    genre: '스릴러',
    year: 2023,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    rating: 3.9,
  ),
  Movie(
    id: 4,
    title: '네 번째 오후',
    genre: '로맨스',
    year: 2022,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    rating: 4.0,
  ),
  Movie(
    id: 5,
    title: '밤의 그림자',
    genre: '액션',
    year: 2023,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    rating: 3.7,
  ),
  Movie(
    id: 6,
    title: '속삭이는 숲',
    genre: '판타지',
    year: 2021,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
  ),
];

/// 목록 화면의 장르 Chip에 쓸 장르 목록. Mock 데이터에서 중복 없이 뽑는다.
final List<String> genres = movies.map((movie) => movie.genre).toSet().toList();

/// Path Parameter로 받은 ID에 해당하는 영화를 찾는다.
///
/// URL을 직접 치거나 ID가 잘못된 경우를 대비해 없으면 `null`을 돌려준다.
Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}
