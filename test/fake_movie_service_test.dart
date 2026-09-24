// 4주차 Mock Service가 성공·빈 목록·실패로 완료되는지 확인하는 Unit 테스트. (Challenge)

import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/mock_movies.dart';
import 'package:movielog/services/fake_movie_service.dart';
import 'package:movielog/services/movie_service.dart';

void main() {
  // 테스트에서는 굳이 1.2초를 기다릴 필요가 없으므로 지연을 짧게 준다.
  FakeMovieService service(MovieLoadMode mode) =>
      FakeMovieService(mode: mode, delay: const Duration(milliseconds: 10));

  test('기본 지연은 Loading 화면이 보이도록 800ms 이상이다', () {
    expect(FakeMovieService().delay.inMilliseconds, greaterThanOrEqualTo(800));
  });

  test('success 모드는 Mock 영화 목록으로 완료된다', () async {
    final result = await service(MovieLoadMode.success).fetchMovies();

    expect(result, movies);
    expect(result, isNotEmpty);
  });

  test('empty 모드는 빈 목록으로 완료된다 (오류가 아니다)', () async {
    final result = await service(MovieLoadMode.empty).fetchMovies();

    expect(result, isEmpty);
  });

  test('failure 모드는 MovieLoadException 오류로 완료된다', () async {
    final call = service(MovieLoadMode.failure).fetchMovies();

    await expectLater(call, throwsA(isA<MovieLoadException>()));
  });

  test('failFirst 모드는 첫 시도만 실패하고 재시도는 성공한다', () async {
    final failFirst = service(MovieLoadMode.failFirst);

    await expectLater(
      failFirst.fetchMovies(),
      throwsA(isA<MovieLoadException>()),
    );
    expect(await failFirst.fetchMovies(), movies);
    expect(failFirst.attempt, 2);
  });

  test('FakeMovieService는 MovieService 자리를 그대로 대신한다', () {
    // 5주차에 실제 API Service로 갈아 끼울 수 있는 구조인지 확인한다.
    expect(service(MovieLoadMode.success), isA<MovieService>());
  });
}
