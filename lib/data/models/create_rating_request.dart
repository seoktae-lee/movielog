/// MovieLog 자체 API에 평점을 저장할 때 보낼 요청 Body.
///
/// 영화 정보는 TMDB가, 평점은 MovieLog 자체 백엔드가 담당한다.
/// 두 데이터를 잇는 값이 [movieId]이고, 여기에는 목록 index가 아니라
/// `TmdbMovieDto.id`를 그대로 넣는다. (실제 전송은 이후 주차에 연결)
class CreateRatingRequest {
  const CreateRatingRequest({required this.movieId, required this.score});

  final int movieId;
  final double score;

  Map<String, dynamic> toJson() => {'movieId': movieId, 'score': score};

  @override
  String toString() => 'CreateRatingRequest(movieId: $movieId, score: $score)';
}
