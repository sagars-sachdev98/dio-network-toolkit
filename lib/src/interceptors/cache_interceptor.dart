import 'package:dio/dio.dart';
import '../core/config.dart';

class _CacheEntry {
  final Response response;
  final DateTime timestamp;
  _CacheEntry(this.response) : timestamp = DateTime.now();
  bool isFresh(Duration maxAge) =>
      DateTime.now().difference(timestamp) < maxAge;
}

/// In-memory GET response cache with configurable strategies.
///
/// - **networkFirst**: fetch from network, cache result, serve cache on failure
/// - **cacheFirst**: serve cache if fresh, else fetch
/// - **staleWhileRevalidate**: serve stale cache immediately, refresh in background
class CacheInterceptor extends Interceptor {
  final CacheConfig _config;
  final Dio? _dio;
  final _cache = <String, _CacheEntry>{};

  /// Creates a [CacheInterceptor] with the given [config] and optional [dio]
  /// instance for background revalidation.
  CacheInterceptor({required CacheConfig config, Dio? dio})
      : _config = config,
        _dio = dio;

  String _key(RequestOptions opts) =>
      '${opts.method}:${opts.uri}:${opts.queryParameters}';

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Only cache GET
    if (options.method.toUpperCase() != 'GET') return handler.next(options);

    // Check exclude paths
    for (final pattern in _config.excludePaths) {
      if (pattern.hasMatch(options.path)) return handler.next(options);
    }

    // Per-request disable or background revalidation
    if (options.extra['noCache'] == true ||
        options.extra['_revalidating'] == true) {
      return handler.next(options);
    }

    final key = _key(options);
    final entry = _cache[key];

    switch (_config.strategy) {
      case CacheStrategy.cacheFirst:
        if (entry != null && entry.isFresh(_config.maxAge)) {
          return handler.resolve(entry.response..requestOptions = options);
        }
        break;

      case CacheStrategy.staleWhileRevalidate:
        if (entry != null) {
          // Return stale immediately
          handler.resolve(entry.response..requestOptions = options);
          // Fire background revalidation (mark to bypass cache)
          final revalidateOpts = options.copyWith(
            extra: {...options.extra, '_revalidating': true},
          );
          _revalidate(revalidateOpts);
          return;
        }
        break;

      case CacheStrategy.networkFirst:
        // Always try network first, cache is fallback in onError
        break;
    }

    handler.next(options);
  }

  /// Fires a background network request to update the cache.
  void _revalidate(RequestOptions options) {
    if (_dio == null) return;
    _dio.fetch(options).then((response) {
      final key = _key(response.requestOptions);
      _cache[key] = _CacheEntry(response);
      _evictIfNeeded();
    }).catchError((_) {
      // Silently ignore — stale data was already served
    });
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method.toUpperCase() == 'GET' &&
        response.requestOptions.extra['noCache'] != true) {
      final key = _key(response.requestOptions);
      _cache[key] = _CacheEntry(response);
      _evictIfNeeded();
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // For networkFirst: serve cache as fallback on network failure
    if (_config.strategy == CacheStrategy.networkFirst &&
        err.requestOptions.method.toUpperCase() == 'GET') {
      final key = _key(err.requestOptions);
      final entry = _cache[key];
      if (entry != null) {
        return handler
            .resolve(entry.response..requestOptions = err.requestOptions);
      }
    }
    handler.next(err);
  }

  void _evictIfNeeded() {
    if (_cache.length > _config.maxEntries) {
      // Remove oldest entries
      final sorted = _cache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      final toRemove = sorted.take(_cache.length - _config.maxEntries);
      for (final entry in toRemove) {
        _cache.remove(entry.key);
      }
    }
  }

  /// Clear all cached entries.
  void clearCache() => _cache.clear();

  /// Clear cache for a specific path.
  void invalidate(String path) => _cache.removeWhere((key, _) {
        // Path-segment-aware matching: require boundary after the path
        // to prevent "/user" from matching "/users"
        final idx = key.indexOf(path);
        if (idx == -1) return false;
        final afterIdx = idx + path.length;
        if (afterIdx >= key.length) return true;
        final next = key[afterIdx];
        return next == '/' || next == '?' || next == ':';
      });
}
