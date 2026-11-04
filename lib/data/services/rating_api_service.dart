import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// MovieLog 평점 API Service. 조회(6주차) + 등록·수정·삭제(7주차).
///
/// API마다 성공 응답 모양이 다르다. 계약에 맞춰 각각 처리한다.
///
/// | 동작 | 성공 |
/// |---|---|
/// | 조회 GET | 200 + 직접 배열 (Wrapper 없음) |
/// | 등록 POST | 201 + Wrapper (result는 확정 전이라 읽지 않음) |
/// | 수정 PATCH | 200 + Wrapper (result null) |
/// | 삭제 DELETE | 204 + body 없음 → 파싱하지 않는다 |
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// memberId 회원의 평점 목록. ratingId 내림차순. (`GET /v6/members/{memberId}/ratings`)
  ///
  /// 평점이 없으면 빈 배열이 온다. 빈 배열은 실패가 아니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// 평점 등록. (`POST /v6/members/{memberId}/ratings`)
  ///
  /// Swagger 설명은 "result는 ratingId 숫자"인데 같은 schema 예시는 null이다.
  /// 계약이 확정되기 전에는 result를 강제 캐스팅하지 않고, 등록 후 GET으로 목록을 다시 확인한다.
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// 평점 수정. (`PATCH /v6/members/{memberId}/ratings/{ratingId}`)
  ///
  /// score는 필수, comment를 빼면 기존 후기가 null로 덮인다.
  /// 기존 후기를 유지하려면 호출하는 쪽이 기존 comment를 그대로 넘긴다.
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: UpdateRatingRequest(score: score, comment: comment).toJson(),
    );
  }

  /// 평점 삭제. (`DELETE /v6/members/{memberId}/ratings/{ratingId}`)
  ///
  /// 성공은 204라 body가 없다. `response.data as Map`을 하지 않는다.
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete(
      '/v6/members/$memberId/ratings/$ratingId',
    );
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 평점 조회 실패를 화면 문구로 바꾼다.
///
/// v6 실패 응답은 공통 형식이다. 400(형식 오류)·404(없는 회원)·그 밖의 실패(네트워크 등)를 하나로 뭉치지 않는다.
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 평점 쓰기(등록·수정·삭제) 실패를 화면 문구로 바꾼다.
///
/// 같은 COMMON404라도 등록에서는 "유저", 수정·삭제에서는 "평점"을 가리킨다.
/// code로 문구를 새로 만들면 이 차이를 놓치므로 서버 message를 그대로 보여 준다.
/// code는 문구가 아니라 다음 UI 행동(다시 조회할지)을 정하는 데만 쓴다. ([shouldRefreshAfterRatingError])
String writeErrorMessage(DioException error) {
  return tryParseCommonError(error.response?.data)?.message ??
      '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 403·404는 화면에 남은 목록이 서버 상태와 어긋났다는 뜻이라 다시 조회해 맞춘다.
///
/// 400(별점 범위)·409(중복 등록)는 같은 화면에서 값만 고치거나 다시 시도하면 되므로 조회하지 않는다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = tryParseCommonError(error.response?.data)?.code;
  return code == 'COMMON403' || code == 'COMMON404';
}

/// Dialog가 onSubmit 실패를 잡았을 때 보여 줄 문구.
///
/// 서버가 보낸 message(400/403/404/409 구분)를 우선하고, 그 외에는 공통 안내.
String submitErrorMessage(Object error) {
  if (error is DioException) return writeErrorMessage(error);
  if (error is StateError) return error.message;
  return '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
