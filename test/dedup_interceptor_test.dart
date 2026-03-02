import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

  group('DedupInterceptor', () {
    test('deduplicates identical concurrent GET requests', () async {
      int fetchCount = 0;
      final fetchCompleter = Completer<void>();

      dio.httpClientAdapter = _DelayedMockAdapter(
        onFetch: (options) {
          fetchCount++;
          return fetchCompleter.future.then((_) => ResponseBody.fromString(
                jsonEncode({'value': 42}),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              ));
        },
      );
      dio.interceptors.add(DedupInterceptor());

      // Fire 3 identical GET requests concurrently
      final f1 = dio.get('/profile');
      final f2 = dio.get('/profile');
      final f3 = dio.get('/profile');

      // Let the adapter complete
      fetchCompleter.complete();

      final results = await Future.wait([f1, f2, f3]);

      // Only 1 actual network request
      expect(fetchCount, 1);
      // All get the same data
      for (final r in results) {
        expect(r.data, {'value': 42});
        expect(r.statusCode, 200);
      }
    });

    test('does not dedup POST requests', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(DedupInterceptor());

      await Future.wait([
        dio.post('/data', data: {}),
        dio.post('/data', data: {}),
      ]);

      expect(adapter.requestCount, 2);
    });

    test('propagates error to all waiting requests', () async {
      int fetchCount = 0;
      final fetchCompleter = Completer<void>();

      dio.httpClientAdapter = _DelayedMockAdapter(
        onFetch: (options) {
          fetchCount++;
          return fetchCompleter.future.then((_) => throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'No connection',
              ));
        },
      );
      dio.interceptors.add(DedupInterceptor());

      final f1 = dio.get('/profile');
      final f2 = dio.get('/profile');

      fetchCompleter.complete();

      await expectLater(f1, throwsA(isA<DioException>()));
      await expectLater(f2, throwsA(isA<DioException>()));
      expect(fetchCount, 1);
    });

    test('noDedup bypasses deduplication', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(DedupInterceptor());

      await Future.wait([
        dio.get('/profile', options: Options(extra: {'noDedup': true})),
        dio.get('/profile', options: Options(extra: {'noDedup': true})),
      ]);

      expect(adapter.requestCount, 2);
    });

    test('different URLs are not deduped', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(DedupInterceptor());

      await Future.wait([
        dio.get('/a'),
        dio.get('/b'),
      ]);

      expect(adapter.requestCount, 2);
    });
  });
}

/// A mock adapter that can delay responses using Futures.
class _DelayedMockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  _DelayedMockAdapter({required this.onFetch});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}
