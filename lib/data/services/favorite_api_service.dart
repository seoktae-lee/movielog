import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/favorite_check_dto.dart';
import '../models/favorite_response_dto.dart';

/// MovieLog 즐겨찾기 API(`/v8/favorites`)를 호출하는 Service. (9주차)
///
/// 보호용 Dio(AuthInterceptor 포함)를 주입받는다. 사용자는 JWT로 구분하므로
/// path·body에 memberId가 없다. 경로의 숫자는 favoriteId가 아니라 **TMDB movieId**다.
///
/// 테스트에서 가짜로 바꿔 끼울 수 있도록 ViewModel은 이 클래스 타입만 안다.
class FavoriteApiService {
  FavoriteApiService(this._dio);

  final Dio _dio;

  /// 즐겨찾기 등록: 201, result에 [FavoriteResponseDto].
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    final response = await _dio.post(
      '/v8/favorites',
      data: {'movieId': movieId},
    );
    final body = CommonResponse<FavoriteResponseDto>.fromJson(
      response.data as Map<String, dynamic>,
      FavoriteResponseDto.fromJson,
    );
    return body.result!;
  }

  /// 내 즐겨찾기 조회: 200, result가 배열이다. 없으면 빈 배열. page 파라미터는 없다.
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    final response = await _dio.get('/v8/favorites');
    final body = CommonResponse<List<FavoriteResponseDto>>.fromJson(
      response.data as Map<String, dynamic>,
      (value) =>
          (value as List<dynamic>).map(FavoriteResponseDto.fromJson).toList(),
    );
    return body.result ?? const [];
  }

  /// 특정 영화의 즐겨찾기 여부: 응답에 movieId가 없어 요청한 값을 함께 넘긴다.
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    final response = await _dio.get('/v8/favorites/$movieId');
    final body = CommonResponse<FavoriteCheckDto>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => FavoriteCheckDto.fromJson(value, movieId: movieId),
    );
    return body.result!;
  }

  /// 즐겨찾기 해제: 200이고 result는 null. 평점 삭제와 달리 응답 body를 파싱하지 않고,
  /// DioException이 없으면 성공으로 본다.
  Future<void> deleteFavorite({required int movieId}) async {
    await _dio.delete('/v8/favorites/$movieId');
  }
}
