/// 화면의 별점(double)을 서버 평점(1~5 정수)으로 바꾼다.
///
/// RatingBar는 항상 double을 돌려준다. 정수 모드로 막아 두었더라도
/// 0.5 같은 값을 조용히 toInt()로 깎지 않고 오류로 드러내는 안전장치다.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// 평점 등록 요청 Body. (`POST /v7/ratings`, memberId 없음)
///
/// 영화 정보는 TMDB가, 평점은 MovieLog 백엔드가 담당한다.
/// 두 데이터를 잇는 값이 [movieId]이고, 목록 index가 아니라 `TmdbMovieDto.id`를 그대로 넣는다.
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  final int movieId;
  final int score;
  final String? comment;

  /// `if` collection: comment가 있을 때만 Map에 넣는다. 등록 comment는 선택이라 빈 문자열 대신 생략한다.
  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };

  @override
  String toString() => 'CreateRatingRequest(${toJson()})';
}

/// 평점 수정 요청 Body. (`PATCH /v7/ratings/{ratingId}`)
///
/// PATCH지만 부분 수정이 아니라 전체 교체다. score는 필수이고,
/// comment를 빼면 기존 후기가 null로 덮인다. 그래서 등록과 달리 comment 키를 **항상** 보낸다.
/// (null을 보내면 "후기를 지운다"는 의도가 명확해진다)
class UpdateRatingRequest {
  const UpdateRatingRequest({required this.score, required this.comment});

  final int score;
  final String? comment;

  Map<String, dynamic> toJson() => {'score': score, 'comment': comment};
}
