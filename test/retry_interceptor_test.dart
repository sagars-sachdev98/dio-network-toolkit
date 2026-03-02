import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';
import 'test_helpers.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test.com'));
  });

  tearDown(() {
    dio.close();
  });

  group('RetryInterceptor', () {
    test('retries up to maxAttempts on 500', () async {
      int fetchCount = 0;
      dio.httpClientAdapter = MockAdapter((options, count) {
        fetchCount = count;
        throw DioException(
          requestOptions: options,
          response: Response(
              requestOptions: options, statusCode: 500, data: 'error'),
          type: DioExceptionType.badResponse,
        );
      });

      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        config: const RetryConfig(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 1),
          useJitter: false,
        ),
      ));

      try {
        await dio.get('/test');
      } catch (_) {}

      // 1 original + 2 retries = 3
      expect(fetchCount, 3);
    });

    test('does not retry non-retryable methods (POST by default)', () async {
      int fetchCount = 0;
      dio.httpClientAdapter = MockAdapter((options, count) {
        fetchCount = count;
        throw DioException(
          requestOptions: options,
          response: Response(
              requestOptions: options, statusCode: 500, data: 'error'),
          type: DioExceptionType.badResponse,
        );
      });

      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        config: const RetryConfig(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 1),
        ),
      ));

      try {
        await dio.post('/test');
      } catch (_) {}

      // Only the original request, no retries
      expect(fetchCount, 1);
    });

    test('respects noRetry extra flag', () async {
      int fetchCount = 0;
      dio.httpClientAdapter = MockAdapter((options, count) {
        fetchCount = count;
        throw DioException(
          requestOptions: options,
          response: Response(
              requestOptions: options, statusCode: 500, data: 'error'),
          type: DioExceptionType.badResponse,
        );
      });

      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        config: const RetryConfig(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 1),
        ),
      ));

      try {
        await dio.get('/test', options: Options(extra: {'noRetry': true}));
      } catch (_) {}

      expect(fetchCount, 1);
    });

    test('succeeds on retry after initial failure', () async {
      int fetchCount = 0;
      dio.httpClientAdapter = MockAdapter((options, count) {
        fetchCount = count;
        if (count <= 1) {
          throw DioException(
            requestOptions: options,
            response: Response(
                requestOptions: options, statusCode: 503, data: 'error'),
            type: DioExceptionType.badResponse,
          );
        }
        return ResponseBody.fromString(
          jsonEncode({'ok': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        config: const RetryConfig(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 1),
          useJitter: false,
        ),
      ));

      final response = await dio.get('/test');
      expect(response.statusCode, 200);
      expect(fetchCount, 2);
    });

    test('respects Retry-After header for 429', () async {
      final stopwatch = Stopwatch()..start();

      dio.httpClientAdapter = MockAdapter((options, count) {
        if (count <= 1) {
          throw DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 429,
              data: null,
              headers: Headers.fromMap({
                'retry-after': ['1'],
              }),
            ),
            type: DioExceptionType.badResponse,
          );
        }
        return ResponseBody.fromString(
          jsonEncode({'ok': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        config: const RetryConfig(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 10),
          useJitter: false,
        ),
      ));

      await dio.get('/test');
      stopwatch.stop();
      // Should have waited ~1 second for Retry-After
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(900));
    });

    test('does not retry non-retryable status codes', () async {
      int fetchCount = 0;
      dio.httpClientAdapter = MockAdapter((options, count) {
        fetchCount = count;
        throw DioException(
          requestOptions: options,
          response: Response(
              requestOptions: options, statusCode: 404, data: 'not found'),
          type: DioExceptionType.badResponse,
        );
      });

      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        config: const RetryConfig(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 1),
        ),
      ));

      try {
        await dio.get('/test');
      } catch (_) {}

      expect(fetchCount, 1);
    });
  });
}
