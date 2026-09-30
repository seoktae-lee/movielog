/// `GET /members/{memberId}/ratings` 응답의 한 항목.
///
/// 영화 정보는 없고 TMDB 영화 id(`movieId`)만 있다.
/// 제목·포스터는 이 id로 TMDB에서 따로 가져온다.
class MemberRatingDto {
  const MemberRatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final int ratingId;

  /// TMDB 영화 id. 우리 DB와 TMDB를 잇는 연결 고리.
  final int movieId;

  /// 1~5점.
  final int score;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MemberRatingDto.fromJson(Map<String, dynamic> json) {
    return MemberRatingDto(
      ratingId: (json['ratingId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      // 서버는 "2026-09-30T10:40:29"처럼 시간대 없는 LocalDateTime을 준다.
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
