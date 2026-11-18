import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 경로별로 정해 둔 상태 코드·Body를 돌려주고, 들어온 요청을 기록한다.
///
/// Key는 `'METHOD /path'`(먼저 찾음) 또는 `'/path'`. Body가 null이면 본문 없이 응답한다. (204)
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.routes);

  final Map<String, (int, Object?)> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    final (status, body) =
        routes['${options.method} $path'] ?? routes[path] ?? (404, const {});
    if (body == null) return ResponseBody.fromString('', status);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
