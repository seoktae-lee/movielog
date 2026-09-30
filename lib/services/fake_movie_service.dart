import '../data/mock_movies.dart';
import '../models/movie.dart';
import 'movie_service.dart';

/// Mock Service가 어떤 결과로 완료될지 정하는 모드.
///
/// 실제 서버라면 상황에 따라 저절로 일어날 일(성공·빈 목록·실패·지연)을
/// 4주차에는 이 enum으로 직접 골라서 재현한다.
enum MovieLoadMode {
  /// Mock 영화 목록을 그대로 돌려준다.
  success('성공'),

  /// 빈 목록으로 완료된다. 오류가 아니라 "정상적인 빈 결과"다.
  empty('빈 목록'),

  /// 항상 [MovieLoadException]으로 완료된다.
  failure('실패'),

  /// 첫 시도만 실패하고 재시도부터 성공한다. 재시도 동작을 보여 줄 때 쓴다.
  failFirst('첫 시도만 실패'),

  /// 응답이 너무 늦어 화면의 `Future.timeout`에 걸린다. (Challenge)
  timeout('응답 지연');

  const MovieLoadMode(this.label);

  /// 디버그 메뉴에 표시할 이름.
  final String label;
}

/// 실제 서버 대신 `Future.delayed`로 비동기 결과를 만들어 주는 Mock Service.
///
/// 화면은 이 클래스가 내부에서 `Future.delayed`를 쓰는지,
/// 5주차처럼 실제 API를 호출하는지 몰라도 되도록 [MovieService]만 구현한다.
class FakeMovieService implements MovieService {
  FakeMovieService({
    this.mode = MovieLoadMode.success,
    this.delay = const Duration(milliseconds: 1200),
  });

  /// 이번 Service 인스턴스가 어떤 결과를 돌려줄지 정한다.
  final MovieLoadMode mode;

  /// Loading 화면이 눈에 보이도록 최소 800ms 이상으로 둔다.
  final Duration delay;

  /// [MovieLoadMode.failFirst]에서 "첫 시도"를 가려내기 위한 호출 횟수.
  int _attempt = 0;

  /// 지금까지 이 인스턴스에 요청이 몇 번 들어왔는지. (테스트·디버그용)
  int get attempt => _attempt;

  @override
  Future<List<Movie>> fetchMovies() async {
    _attempt++;

    // 응답 지연 모드는 화면의 timeout(5초)보다 길게 기다린다.
    await Future<void>.delayed(
      mode == MovieLoadMode.timeout ? const Duration(seconds: 10) : delay,
    );

    return switch (mode) {
      MovieLoadMode.success => movies,
      MovieLoadMode.timeout => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure => throw const MovieLoadException(
        '영화 목록을 불러오지 못했습니다.',
      ),
      MovieLoadMode.failFirst =>
        _attempt == 1
            ? throw const MovieLoadException('영화 목록을 불러오지 못했습니다.')
            : movies,
    };
  }
}
