import '../services/sort_preference.dart';
import 'movie.dart';

/// 영화 목록 화면이 처음 그려지기 위해 필요한 값 묶음.
///
/// "영화 목록"과 "마지막에 고른 장르·정렬"은 서로를 기다릴 필요가 없어
/// `Future.wait`로 함께 시작하고, 결과를 이 클래스 하나로 모아 전달한다.
class MovieListInitialData {
  const MovieListInitialData({
    required this.movies,
    required this.selectedGenres,
    required this.sortOption,
  });

  /// Service가 돌려준 영화 목록. 빈 목록도 정상 결과다.
  final List<Movie> movies;

  /// 저장돼 있던 마지막 선택 장르. 비어 있으면 전체.
  final Set<String> selectedGenres;

  /// 저장돼 있던 마지막 정렬 기준.
  final MovieSortOption sortOption;
}
