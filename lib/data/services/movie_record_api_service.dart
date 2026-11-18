import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/movie_record_models.dart';

/// 평점과 즐겨찾기를 한 번에 저장하는 API(`POST /v8/movie-records`). (9주차 Challenge)
///
/// 보호용 Dio를 주입받는다. 서버가 한 트랜잭션으로 처리하므로 한쪽이 실패하면 둘 다 저장되지 않는다.
class MovieRecordApiService {
  MovieRecordApiService(this._dio);

  final Dio _dio;

  Future<MovieRecordResponse> saveMovieRecord(
    MovieRecordRequest request,
  ) async {
    final response = await _dio.post(
      '/v8/movie-records',
      data: request.toJson(),
    );
    final body = CommonResponse<MovieRecordResponse>.fromJson(
      response.data as Map<String, dynamic>,
      MovieRecordResponse.fromJson,
    );
    return body.result!;
  }
}
