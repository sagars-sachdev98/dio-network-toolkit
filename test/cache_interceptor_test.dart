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

  group('CacheStrategy.cacheFirst', () {
    test('serves cached response on second request', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: Duration(minutes: 5),
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      final r1 = await dio.get('/data');
      final r2 = await dio.get('/data');

      expect(adapter.requestCount, 1);
      expect(r1.data, {'count': 1});
      expect(r2.data, {'count': 1});
    });

    test('fetches again after cache expires', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: Duration(milliseconds: 50),
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      await dio.get('/data');
      await Future.delayed(const Duration(milliseconds: 60));
      await dio.get('/data');

      expect(adapter.requestCount, 2);
    });
  });

  group('CacheStrategy.networkFirst', () {
    test('serves from network when available', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(strategy: CacheStrategy.networkFirst),
      );
      dio.interceptors.add(cacheInterceptor);

      final r1 = await dio.get('/data');
      final r2 = await dio.get('/data');

      expect(adapter.requestCount, 2);
      expect(r1.data, {'count': 1});
      expect(r2.data, {'count': 2});
    });

    test('falls back to cache on network error', () async {
      final adapter = MockAdapter.succeedThenFail(succeedCount: 1);
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(strategy: CacheStrategy.networkFirst),
      );
      dio.interceptors.add(cacheInterceptor);

      final r1 = await dio.get('/data');
      expect(r1.data, {'count': 1});

      // Second request fails at transport, cache fallback should kick in
      final r2 = await dio.get('/data');
      expect(r2.data, {'count': 1});
    });
  });

  group('CacheStrategy.staleWhileRevalidate', () {
    test('returns stale cache and fires background revalidation', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.staleWhileRevalidate,
          maxAge: Duration(minutes: 5),
        ),
        dio: dio,
      );
      dio.interceptors.add(cacheInterceptor);

      // First request — hits network
      final r1 = await dio.get('/data');
      expect(r1.data, {'count': 1});
      expect(adapter.requestCount, 1);

      // Second request — returns stale cache immediately
      final r2 = await dio.get('/data');
      expect(r2.data, {'count': 1}); // stale data served

      // Wait for background revalidation to complete
      await Future.delayed(const Duration(milliseconds: 200));
      expect(adapter.requestCount, 2); // background request fired
    });
  });

  group('Cache control', () {
    test('noCache bypasses cache', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: Duration(minutes: 5),
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      await dio.get('/data');
      await dio.get('/data', options: Options(extra: {'noCache': true}));

      expect(adapter.requestCount, 2);
    });

    test('does not cache non-GET requests', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: Duration(minutes: 5),
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      await dio.post('/data', data: {});
      await dio.post('/data', data: {});

      expect(adapter.requestCount, 2);
    });

    test('clearCache removes all entries', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: Duration(minutes: 5),
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      await dio.get('/data');
      cacheInterceptor.clearCache();
      await dio.get('/data');

      expect(adapter.requestCount, 2);
    });

    test('excludePaths skips matching paths', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: const Duration(minutes: 5),
          excludePaths: [RegExp(r'/live')],
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      await dio.get('/live');
      await dio.get('/live');

      expect(adapter.requestCount, 2);
    });
  });

  group('Cache invalidation precision', () {
    test('invalidating /user does not remove /users', () async {
      final adapter = MockAdapter.json(
          (opts, count) => {'path': opts.path, 'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: Duration(minutes: 5),
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      await dio.get('/user');
      await dio.get('/users');
      expect(adapter.requestCount, 2);

      // Invalidate /user only
      cacheInterceptor.invalidate('/user');

      // /user should need re-fetch
      await dio.get('/user');
      expect(adapter.requestCount, 3);

      // /users should still be cached
      await dio.get('/users');
      expect(adapter.requestCount, 3);
    });

    test('invalidating /user removes /user?page=1', () async {
      final adapter = MockAdapter.json((_, count) => {'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: Duration(minutes: 5),
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      await dio.get('/user', queryParameters: {'page': '1'});
      expect(adapter.requestCount, 1);

      cacheInterceptor.invalidate('/user');

      await dio.get('/user', queryParameters: {'page': '1'});
      expect(adapter.requestCount, 2);
    });
  });

  group('Eviction', () {
    test('evicts oldest entries when maxEntries exceeded', () async {
      final adapter = MockAdapter.json(
          (opts, count) => {'path': opts.path, 'count': count});
      dio.httpClientAdapter = adapter;

      final cacheInterceptor = CacheInterceptor(
        config: const CacheConfig(
          strategy: CacheStrategy.cacheFirst,
          maxAge: Duration(minutes: 5),
          maxEntries: 2,
        ),
      );
      dio.interceptors.add(cacheInterceptor);

      await dio.get('/a'); // cache: {/a}
      await dio.get('/b'); // cache: {/a, /b}
      await dio.get('/c'); // cache over max(2), evict /a → cache: {/b, /c}
      expect(adapter.requestCount, 3);

      // /a should need re-fetch since evicted
      await dio.get('/a'); // cache over max(2), evict /b → cache: {/c, /a}
      expect(adapter.requestCount, 4);

      // /c should still be cached
      await dio.get('/c');
      expect(adapter.requestCount, 4);
    });
  });
}
