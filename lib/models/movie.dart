/// 영화 한 편을 표현하는 모델 클래스.
///
/// 0주차에서는 Named Parameter와 `required`, 그리고 불변 객체를 만드는
/// `const` 생성자를 연습하기 위해 사용한다.
class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    this.rating,
  });

  final int id;
  final String title;
  final String genre;

  /// 아직 평점을 남기지 않았을 수 있으므로 nullable로 둔다.
  final double? rating;

  /// 평점이 없으면 `평점 없음`으로 대체해서 보여준다.
  String get ratingLabel =>
      rating == null ? '평점 없음' : '${rating!.toStringAsFixed(1)}점';

  @override
  String toString() => 'Movie($id, $title, $genre, $ratingLabel)';
}
