import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';
import 'test_helpers.dart';

void main() {
  late Dio dio;
  late Dio refreshDio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test.com'));
    refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test.com'));
  });

  tearDown(() {
    dio.close();
    refreshDio.close();
  });

  group('Token injection', () {
    test('adds Authorization header when token is present', () async {
      RequestOptions? captured;
      dio.interceptors.add(AuthInterceptor(
        config: AuthConfig(tokenProvider: () async => 'abc123'),
        refreshDio: refreshDio,
      ));
      dio.httpClientAdapter = MockAdapter((options, _) {
        captured = options;
        return ResponseBody.fromString(
          jsonEncode({'ok': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await dio.get('/test');
      expect(captured!.headers['Authorization'], 'Bearer abc123');
    });

    test('skips token for isPublic requests', () async {
      RequestOptions? captured;
      dio.interceptors.add(AuthInterceptor(
        config: AuthConfig(tokenProvider: () async => 'abc123'),
        refreshDio: refreshDio,
      ));
      dio.httpClientAdapter = MockAdapter((options, _) {
        captured = options;
        return ResponseBody.fromString(
          jsonEncode({'ok': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await dio.get('/test', options: Options(extra: {'isPublic': true}));
      expect(captured!.headers['Authorization'], isNull);
    });

    test('skips token when tokenProvider returns null', () async {
      RequestOptions? captured;
      dio.interceptors.add(AuthInterceptor(
        config: AuthConfig(tokenProvider: () async => null),
        refreshDio: refreshDio,
      ));
      dio.httpClientAdapter = MockAdapter((options, _) {
        captured = options;
        return ResponseBody.fromString(
          jsonEncode({'ok': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await dio.get('/test');
      expect(captured!.headers['Authorization'], isNull);
    });

    test('uses custom headerKey and prefix', () async {
      RequestOptions? captured;
      dio.interceptors.add(AuthInterceptor(
        config: AuthConfig(
          tokenProvider: () async => 'mytoken',
          headerKey: 'X-Token',
          tokenPrefix: 'Token ',
        ),
        refreshDio: refreshDio,
      ));
      dio.httpClientAdapter = MockAdapter((options, _) {
        captured = options;
        return ResponseBody.fromString(
          jsonEncode({'ok': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await dio.get('/test');
      expect(captured!.headers['X-Token'], 'Token mytoken');
    });
  });

  group('401 refresh', () {
    test('calls onTokenExpired when refreshToken returns null', () async {
      bool tokenExpired = false;

      // Main dio returns 401
      dio.httpClientAdapter = MockAdapter((options, _) {
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: null,
          ),
          type: DioExceptionType.badResponse,
        );
      });

      dio.interceptors.add(AuthInterceptor(
        config: AuthConfig(
          tokenProvider: () async => 'expired',
          refreshToken: (dio) async => null,
          onTokenExpired: () => tokenExpired = true,
        ),
        refreshDio: refreshDio,
      ));

      try {
        await dio.get('/protected');
      } catch (_) {}

      expect(tokenExpired, isTrue);
    });

    test('calls onTokenExpired when refreshToken throws', () async {
      bool tokenExpired = false;

      dio.httpClientAdapter = MockAdapter((options, _) {
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: null,
          ),
          type: DioExceptionType.badResponse,
        );
      });

      dio.interceptors.add(AuthInterceptor(
        config: AuthConfig(
          tokenProvider: () async => 'expired',
          refreshToken: (dio) async => throw Exception('refresh failed'),
          onTokenExpired: () => tokenExpired = true,
        ),
        refreshDio: refreshDio,
      ));

      try {
        await dio.get('/protected');
      } catch (_) {}

      expect(tokenExpired, isTrue);
    });

    test('retries with new token after successful refresh', () async {
      dio.httpClientAdapter = MockAdapter((options, count) {
        if (options.extra['_isRetryAfterRefresh'] != true) {
          throw DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              data: null,
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

      refreshDio.httpClientAdapter = MockAdapter((options, _) {
        return ResponseBody.fromString(
          jsonEncode({'ok': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      dio.interceptors.add(AuthInterceptor(
        config: AuthConfig(
          tokenProvider: () async => 'expired',
          refreshToken: (dio) async => 'newtoken',
        ),
        refreshDio: refreshDio,
      ));

      final response = await dio.get('/protected');
      expect(response.statusCode, 200);
    });

    test('does not refresh for isPublic requests', () async {
      int refreshCount = 0;

      dio.httpClientAdapter = MockAdapter((options, _) {
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: null,
          ),
          type: DioExceptionType.badResponse,
        );
      });

      dio.interceptors.add(AuthInterceptor(
        config: AuthConfig(
          tokenProvider: () async => 'token',
          refreshToken: (dio) async {
            refreshCount++;
            return 'new';
          },
        ),
        refreshDio: refreshDio,
      ));

      try {
        await dio.get('/public', options: Options(extra: {'isPublic': true}));
      } catch (_) {}

      expect(refreshCount, 0);
    });
  });
}
