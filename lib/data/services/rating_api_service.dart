import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 평점 쓰기 응답(공통 형식)에서 Rating을 꺼낸다. v7 등록·수정 result는 Rating 객체다.
RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}

/// 유저별 평점 조회 성공 응답은 공통 형식이 아니라 **직접 배열**이다.
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

/// MovieLog 평점 API Service. 8주차에 v6 → v7로 전환했다.
///
/// | 동작 | v6 | v7 |
/// |---|---|---|
/// | 등록 | `POST /v6/members/{memberId}/ratings` | `POST /v7/ratings` (201, result = Rating) |
/// | 수정 | `PATCH /v6/members/{memberId}/ratings/{id}` | `PATCH /v7/ratings/{id}` (200, result = Rating) |
/// | 삭제 | 같은 memberId 포함, 204 | `DELETE /v7/ratings/{id}` (200, result null) |
/// | 사용자 식별 | path의 memberId | `Authorization: Bearer ...` |
///
/// Dio를 두 개 받는다. 조회는 공개 API라 공개용, 쓰기는 보호용 Client로 보낸다.
/// 어느 Client를 쓸지는 Service가 메서드마다 정하므로 ViewModel은 Dio를 몰라도 된다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  /// 공개 조회: `GET /v7/members/{memberId}/ratings`. 토큰 없이 호출한다.
  ///
  /// v7 로그인·내 정보 응답에 memberId가 없으므로, 로그인한 "나"의 목록을 이 API로 복원할 수는 없다.
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get('/v7/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  /// 등록. body에 memberId를 넣지 않는다. (넣을 자리 자체가 없다)
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v7/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  /// 수정. PATCH지만 **전체 교체**라 comment를 빼면 기존 후기가 null로 덮인다.
  /// 그래서 Dialog에 기존 score·comment를 채워 두고 두 값을 항상 함께 보낸다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: UpdateRatingRequest(score: score, comment: comment).toJson(),
    );
    return parseRatingResult(response.data);
  }

  /// 삭제. v7 성공은 204가 아니라 200 + `{..., result: null}`이다.
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v7/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 평점 쓰기(등록·수정·삭제) 실패를 화면 문구로 바꾼다. v7 도메인 code 기준.
///
/// - `RATING403_1`: 남의 평점 → 안내만, 로그아웃하지 않는다.
/// - `RATING409_1`: 이미 이 영화에 평점이 있다.
/// - `RATING404_1`: 이미 지워진 평점.
/// - `COMMON400`: 별점 범위 등 입력 검증 → 서버 message 그대로.
/// - 세션 만료(AUTH401_2/3/4)는 ViewModel이 먼저 가로채 세션을 정리한다.
String writeErrorMessage(DioException error) {
  final serverMessage = apiErrorMessage(error);
  return switch (apiErrorCode(error)) {
    'RATING403_1' => '본인이 작성한 평점만 수정하거나 삭제할 수 있어요.',
    'RATING409_1' => '이미 이 영화에 평점을 남겼어요. 기존 기록을 확인해 주세요.',
    'RATING404_1' => '이미 삭제됐거나 찾을 수 없는 평점이에요.',
    'MEMBER404_1' => '회원 정보를 찾을 수 없어요. 다시 로그인해 주세요.',
    _ when sessionExpiredCodes.contains(apiErrorCode(error)) =>
      '로그인이 만료됐어요. 다시 로그인해 주세요.',
    _ when serverMessage != null => serverMessage,
    _ => '요청에 실패했어요. 네트워크 상태를 확인하고 다시 시도해 주세요.',
  };
}

/// Dialog가 onSubmit 실패를 잡았을 때 보여 줄 문구.
String submitErrorMessage(Object error) {
  if (error is DioException) return writeErrorMessage(error);
  if (error is StateError) return error.message;
  return '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
