/// `GET /v6/members/{memberId}/ratings` 응답 배열의 한 항목.
///
/// 영화 정보는 없고 TMDB 영화 id(`movieId`)만 있다.
/// 제목·포스터는 이 id로 TMDB에서 따로 가져온다. ([RatingWithMovie])
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
  });

  final int ratingId;

  /// TMDB 영화 id. 자체 백엔드와 TMDB를 잇는 연결 고리.
  final int movieId;

  /// 1~5점.
  final int score;

  /// 명세에 `nullable: true`. 후기 없이 점수만 남길 수 있다.
  final String? comment;

  /// `2026-09-06T12:14:03.000Z`처럼 UTC(Z)로 온다.
  final DateTime createdAt;

  factory RatingDto.fromJson(Map<String, dynamic> json) => RatingDto(
    // JSON 숫자는 int·double 어느 쪽으로도 올 수 있어 num으로 받고 변환한다.
    ratingId: (json['ratingId'] as num).toInt(),
    movieId: (json['movieId'] as num).toInt(),
    score: (json['score'] as num).toInt(),
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
