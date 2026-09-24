import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie.dart';

/// 영화 목록 정렬 기준. (Challenge: 장르뿐 아니라 정렬 방식도 저장한다)
enum MovieSortOption {
  latest('최신순'),
  rating('평점 높은순'),
  title('가나다순');

  const MovieSortOption(this.label);

  final String label;
}

/// 정렬 기준을 기기에 저장하고 읽어 오는 클래스.
class SortPreference {
  SortPreference({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const sortOptionKey = 'movie_sort_option';

  final SharedPreferencesAsync _preferences;

  /// 저장된 정렬 기준. 저장한 적이 없거나 모르는 값이면 [MovieSortOption.latest].
  Future<MovieSortOption> read() async {
    final saved = await _preferences.getString(sortOptionKey);
    // enum은 그대로 저장할 수 없으므로 name(String)으로 바꿔 저장하고 되돌린다.
    return MovieSortOption.values.firstWhere(
      (option) => option.name == saved,
      orElse: () => MovieSortOption.latest,
    );
  }

  Future<void> save(MovieSortOption option) =>
      _preferences.setString(sortOptionKey, option.name);

  Future<void> clear() => _preferences.remove(sortOptionKey);
}

/// 정렬 기준에 맞춰 영화 목록의 복사본을 정렬해서 돌려준다.
///
/// 원본 Mock 목록(`const List<Movie> movies`)은 정렬로 바뀌면 안 되므로
/// 반드시 복사본을 만들어 정렬한다.
List<Movie> sortMovies(List<Movie> movies, MovieSortOption option) {
  final sorted = [...movies];
  switch (option) {
    case MovieSortOption.latest:
      sorted.sort((a, b) => b.year.compareTo(a.year));
    case MovieSortOption.rating:
      // 평점이 없는 영화(null)는 뒤로 보낸다.
      sorted.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
    case MovieSortOption.title:
      sorted.sort((a, b) => a.title.compareTo(b.title));
  }
  return sorted;
}
