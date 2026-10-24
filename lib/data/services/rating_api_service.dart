import 'package:dio/dio.dart';

import '../models/rating_dto.dart';

/// 유저별 평점 조회 API를 호출하는 Service.
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// memberId 회원의 평점 목록. ratingId 내림차순. (`GET /v5/members/{memberId}/ratings`)
  ///
  /// 평점이 없으면 빈 배열이 온다. 빈 배열은 실패가 아니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v5/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

/// 평점 조회 실패를 화면 문구로 바꾼다.
///
/// v5 실패 응답은 `{ message, error, statusCode }` 형식이다.
/// 400(형식 오류)·404(없는 회원)·그 밖의 실패(네트워크 등)를 하나로 뭉치지 않는다.
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
