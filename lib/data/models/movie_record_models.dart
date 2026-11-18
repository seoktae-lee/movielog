import 'favorite_response_dto.dart';
import 'rating_dto.dart';

/// 영화 기록 저장 요청 Body. (`POST /v8/movie-records`, Challenge)
///
/// 평점과 즐겨찾기를 한 번에 저장한다. 서버가 한 트랜잭션으로 처리하므로
/// 둘 중 하나라도 실패하면 모두 저장되지 않는다.
/// [addToFavorites]는 필수 boolean이라 false여도 **항상** 보낸다.
class MovieRecordRequest {
  const MovieRecordRequest({
    required this.movieId,
    required this.score,
    this.comment,
    required this.addToFavorites,
  });

  final int movieId;
  final int score;
  final String? comment;
  final bool addToFavorites;

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
    'addToFavorites': addToFavorites,
  };
}

/// 영화 기록 저장 result. `addToFavorites`가 false였다면 [favorite]은 null이 정상이다.
class MovieRecordResponse {
  const MovieRecordResponse({required this.rating, this.favorite});

  factory MovieRecordResponse.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('MovieRecordResponse must be a JSON object.');
    }
    final favorite = json['favorite'];
    return MovieRecordResponse(
      rating: RatingDto.fromJson(json['rating'] as Map<String, dynamic>),
      favorite: favorite == null
          ? null
          : FavoriteResponseDto.fromJson(favorite),
    );
  }

  final RatingDto rating;
  final FavoriteResponseDto? favorite;
}
