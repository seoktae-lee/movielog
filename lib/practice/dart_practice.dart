import 'package:flutter/foundation.dart';

import '../models/movie.dart';

/// 0주차 Mission 2 - Dart 최소 문법 연습.
///
/// 앱 UI와는 분리된 학습용 코드이며, 디버그 모드에서 콘솔 출력으로 결과를 확인한다.

/// 연습에 사용할 영화 3개.
const List<Movie> sampleMovies = <Movie>[
  Movie(
    id: 1,
    title: '인터스텔라',
    genre: 'SF',
    year: 2014,
    posterAsset: '',
    rating: 4.8,
  ),
  Movie(
    id: 2,
    title: '너의 이름은.',
    genre: '애니메이션',
    year: 2016,
    posterAsset: '',
    rating: 4.5,
  ),
  Movie(id: 3, title: '기생충', genre: '드라마', year: 2019, posterAsset: ''),
];

/// nullable 닉네임을 안전한 기본값으로 변환한다.
///
/// - `null`인 경우
/// - 빈 문자열이거나 공백만 있는 경우
///
/// 위 두 경우 모두 `이름 없음`을 돌려준다.
String displayName(String? nickname) {
  final String trimmed = nickname?.trim() ?? '';
  return trimmed.isEmpty ? '이름 없음' : trimmed;
}

/// Named Parameter와 기본값을 연습하는 인사 함수.
String greeting({required String name, int week = 0}) {
  return '$name님, Flutter $week주차를 시작합니다.';
}

/// for 문으로 영화 제목을 출력한다.
void printTitlesWithFor() {
  debugPrint('--- for 문으로 출력 ---');
  for (final Movie movie in sampleMovies) {
    debugPrint(
      '${movie.id}. ${movie.title} (${movie.genre}) · ${movie.ratingLabel}',
    );
  }
}

/// map으로 제목만 뽑아 한 줄로 출력한다.
void printTitlesWithMap() {
  final List<String> titles = sampleMovies
      .map((Movie movie) => movie.title)
      .toList();
  debugPrint('--- map으로 뽑은 제목 ---');
  debugPrint(titles.join(', '));
}

/// Null Safety 변환 결과를 출력한다.
void printDisplayNames() {
  const List<String?> nicknames = <String?>['무비러버', null, '   ', ' 석태 '];
  debugPrint('--- nullable 닉네임 변환 ---');
  for (final String? nickname in nicknames) {
    debugPrint(
      '${nickname.toString().padRight(8)} -> ${displayName(nickname)}',
    );
  }
}

/// Mission 2 전체를 한 번에 실행한다.
void runDartPractice() {
  debugPrint(greeting(name: displayName('무비러버')));
  printTitlesWithFor();
  printTitlesWithMap();
  printDisplayNames();
}
