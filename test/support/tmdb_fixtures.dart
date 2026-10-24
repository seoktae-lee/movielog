// 실제 TMDB 응답 모양을 흉내 낸 테스트용 JSON(fixture).
//
// UI Layer 테스트는 이 값이 실제 서버에서 왔는지 fixture인지 몰라도 된다.

Map<String, dynamic> movieJson(
  int id, {
  String? title,
  String? posterPath,
  String? releaseDate = '2025-07-01',
  List<int> genreIds = const [28],
  num voteAverage = 7.5,
}) {
  return {
    'id': id,
    'title': title ?? '영화 $id',
    'overview': '줄거리 $id',
    'poster_path': posterPath,
    'backdrop_path': null,
    'release_date': releaseDate,
    'genre_ids': genreIds,
    'vote_average': voteAverage,
    'popularity': 100 - id,
  };
}

/// [ids]를 results로 가진 페이지 응답.
Map<String, dynamic> pageJson(
  List<int> ids, {
  int page = 1,
  int totalPages = 500,
}) {
  return {
    'page': page,
    'results': [for (final id in ids) movieJson(id)],
    'total_pages': totalPages,
    'total_results': totalPages * 20,
  };
}

/// start부터 count개의 연속된 id.
List<int> idRange(int start, int count) => [
  for (var i = 0; i < count; i++) start + i,
];

const genresJson = {
  'genres': [
    {'id': 28, 'name': '액션'},
    {'id': 12, 'name': '모험'},
    {'id': 16, 'name': '애니메이션'},
    {'id': 18, 'name': '드라마'},
  ],
};
