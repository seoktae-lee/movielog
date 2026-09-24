import '../models/movie.dart';

/// 영화 목록을 가져오는 통로.
///
/// 화면은 "누가" 영화를 가져오는지 알 필요가 없고, 이 타입만 알고 있으면 된다.
/// 4주차에는 `FakeMovieService`가 `Future.delayed`로 흉내만 내고,
/// 5주차부터는 실제 서버를 호출하는 Service가 같은 자리를 대신한다.
///
/// TODO(5주차 유저별 평점 조회 API): Swagger v5의 유저별 평점 조회 API를 호출하는
/// `RemoteMovieService implements MovieService`를 만들고,
/// `MovieListScreen(movieService: ...)`에 넘기는 구현체만 바꾼다.
/// 화면의 FutureBuilder·Loading·Empty·Error 코드는 그대로 두어도 되도록 이 경계를 유지한다.
abstract interface class MovieService {
  /// 값(영화 목록) 또는 [MovieLoadException] 오류로 완료되는 Future를 돌려준다.
  Future<List<Movie>> fetchMovies();
}

/// 영화를 불러오지 못했을 때 Service가 던지는 예외.
///
/// 화면에는 [message]처럼 사용자가 읽을 수 있는 문구만 쓰고,
/// StackTrace나 내부 예외(SocketException 등)는 그대로 노출하지 않는다.
class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}
