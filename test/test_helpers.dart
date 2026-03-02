import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// Creates a [DioException] for testing.
DioException makeDioException({
  DioExceptionType type = DioExceptionType.badResponse,
  int? statusCode,
  dynamic data,
  String? message,
  Map<String, List<String>>? headers,
  String method = 'GET',
  String path = '/test',
}) {
  final opts = RequestOptions(path: path, method: method);
  return DioException(
    requestOptions: opts,
    type: type,
    message: message,
    response: statusCode != null
        ? Response(
            requestOptions: opts,
            statusCode: statusCode,
            data: data,
            headers: Headers.fromMap(headers ?? {}),
          )
        : null,
  );
}

/// A simple mock [HttpClientAdapter] for testing interceptors at the
/// transport layer, so the full interceptor chain works correctly.
class MockAdapter implements HttpClientAdapter {
  int requestCount = 0;
  final ResponseBody Function(RequestOptions options, int requestCount)
      onFetch;

  MockAdapter(this.onFetch);

  /// Creates a mock adapter that always returns JSON with the given status.
  factory MockAdapter.json(
    dynamic Function(RequestOptions options, int requestCount) dataBuilder, {
    int statusCode = 200,
  }) {
    return MockAdapter((options, count) {
      final data = dataBuilder(options, count);
      return ResponseBody.fromString(
        jsonEncode(data),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
  }

  /// Creates a mock adapter that fails with a connection error.
  factory MockAdapter.error() {
    return MockAdapter((options, _) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Mock connection error',
      );
    });
  }

  /// Creates a mock adapter that succeeds N times, then fails.
  factory MockAdapter.succeedThenFail({
    required int succeedCount,
    dynamic Function(RequestOptions, int)? dataBuilder,
  }) {
    return MockAdapter((options, count) {
      if (count <= succeedCount) {
        final data = dataBuilder?.call(options, count) ?? {'count': count};
        return ResponseBody.fromString(
          jsonEncode(data),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Mock connection error after $succeedCount successes',
      );
    });
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    return onFetch(options, requestCount);
  }

  @override
  void close({bool force = false}) {}
}
