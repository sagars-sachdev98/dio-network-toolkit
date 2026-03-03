import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../result/result.dart';
import '../result/network_error.dart';
import '../interceptors/auth_interceptor.dart';
import '../interceptors/retry_interceptor.dart';
import '../interceptors/connectivity_interceptor.dart';
import '../interceptors/cache_interceptor.dart';
import '../interceptors/dedup_interceptor.dart';
import '../interceptors/logging_interceptor.dart';
import '../offline/offline_request_queue.dart';
import '../upload/upload_manager.dart';
import 'config.dart';

/// Converts a JSON response into a typed object.
typedef FromJson<T> = T Function(dynamic json);

/// Production-ready network layer. Create once, inject everywhere.
///
/// ```dart
/// // Setup (DI)
/// final toolkit = NetworkToolkit(NetworkToolkitConfig(
///   baseUrl: 'https://api.example.com',
///   auth: AuthConfig(tokenProvider: () => storage.read('token')),
///   retry: RetryConfig(maxAttempts: 3),
///   cache: CacheConfig(strategy: CacheStrategy.networkFirst),
///   offlineQueue: OfflineQueueConfig(enabled: true),
///   onError: (e) => showToast(e.userMessage ?? 'Error'),
/// ));
///
/// // Use
/// final result = await toolkit.get<User>('/me', fromJson: User.fromJson);
/// ```
class NetworkToolkit {
  late final Dio _dio;
  late final Dio _refreshDio;
  final NetworkToolkitConfig _config;

  /// File upload manager for single, multi-file, and bytes uploads.
  late final UploadManager upload;
  OfflineRequestQueue? _offlineQueue;
  CacheInterceptor? _cacheInterceptor;

  /// Creates a [NetworkToolkit] with the given [config] and initializes
  /// all interceptors, the upload manager, and the offline queue.
  NetworkToolkit(this._config) {
    _refreshDio = Dio(BaseOptions(
      baseUrl: _config.baseUrl,
      headers: _config.defaultHeaders,
    ));
    _dio = _buildDio();
    upload = UploadManager(_dio);

    if (_config.offlineQueue != null && _config.offlineQueue!.enabled) {
      _offlineQueue = OfflineRequestQueue(
        dio: _dio,
        config: _config.offlineQueue!,
      );
    }
  }

  /// Underlying Dio instance for advanced use cases.
  Dio get dio => _dio;

  /// Access the offline queue (if configured).
  OfflineRequestQueue? get offlineQueue => _offlineQueue;

  /// Access the cache (if configured).
  CacheInterceptor? get cacheInterceptor => _cacheInterceptor;

  Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: _config.connectTimeout,
      receiveTimeout: _config.receiveTimeout,
      sendTimeout: _config.sendTimeout,
      headers: _config.defaultHeaders,
    ));

    // ── Interceptor order matters! ──

    // 1. Logging (logs raw request before anything modifies it)
    if (_config.enableLogging && kDebugMode) {
      dio.interceptors.add(PrettyLogInterceptor(logPrint: _config.logPrinter));
    }

    // 2. Deduplication (prevents duplicate in-flight GETs)
    dio.interceptors.add(DedupInterceptor());

    // 3. Cache (may short-circuit request entirely)
    if (_config.cache != null && _config.cache!.maxAge > Duration.zero) {
      _cacheInterceptor = CacheInterceptor(config: _config.cache!, dio: dio);
      dio.interceptors.add(_cacheInterceptor!);
    }

    // 4. Connectivity (fail fast if no network)
    dio.interceptors.add(ConnectivityInterceptor());

    // 5. Auth (adds token, handles 401 refresh)
    if (_config.auth != null) {
      dio.interceptors.add(AuthInterceptor(
        config: _config.auth!,
        refreshDio: _refreshDio,
      ));
    }

    // 6. Retry (retries after all other interceptors have run)
    if (_config.retry.maxAttempts > 0) {
      dio.interceptors.add(RetryInterceptor(dio: dio, config: _config.retry));
    }

    // 7. User's extra interceptors
    dio.interceptors.addAll(_config.extraInterceptors);

    return dio;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HTTP METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Sends a GET request and parses the response using [fromJson].
  Future<Result<T>> get<T>(
    String path, {
    required FromJson<T> fromJson,
    Map<String, dynamic>? queryParameters,
    bool isPublic = false,
    bool noCache = false,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeCall(
        () => _dio.get(path,
            queryParameters: queryParameters,
            options: _opts(options, isPublic: isPublic, extra: {
              if (noCache) 'noCache': true,
            }),
            cancelToken: cancelToken),
        fromJson: fromJson,
      );

  /// Sends a GET request and parses the response as a list using [fromJson].
  Future<Result<List<T>>> getList<T>(
    String path, {
    required FromJson<T> fromJson,
    String? dataKey,
    Map<String, dynamic>? queryParameters,
    bool isPublic = false,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeCall(
        () => _dio.get(path,
            queryParameters: queryParameters,
            options: _opts(options, isPublic: isPublic),
            cancelToken: cancelToken),
        fromJson: (json) {
          dynamic list;
          if (dataKey != null) {
            if (json is! Map) {
              throw FormatException(
                  'Expected Map for dataKey lookup, got ${json.runtimeType}');
            }
            list = json[dataKey];
          } else {
            list = json;
          }
          if (list is! List) {
            throw FormatException(
                'Expected List, got ${list.runtimeType}');
          }
          return list.map((e) => fromJson(e)).toList();
        },
      );

  /// Sends a POST request and parses the response using [fromJson].
  Future<Result<T>> post<T>(
    String path, {
    required FromJson<T> fromJson,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isPublic = false,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeCall(
        () => _dio.post(path,
            data: data,
            queryParameters: queryParameters,
            options: _opts(options, isPublic: isPublic),
            cancelToken: cancelToken),
        fromJson: fromJson,
      );

  /// Sends a PUT request and parses the response using [fromJson].
  Future<Result<T>> put<T>(
    String path, {
    required FromJson<T> fromJson,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isPublic = false,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeCall(
        () => _dio.put(path,
            data: data,
            queryParameters: queryParameters,
            options: _opts(options, isPublic: isPublic),
            cancelToken: cancelToken),
        fromJson: fromJson,
      );

  /// Sends a PATCH request and parses the response using [fromJson].
  Future<Result<T>> patch<T>(
    String path, {
    required FromJson<T> fromJson,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isPublic = false,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeCall(
        () => _dio.patch(path,
            data: data,
            queryParameters: queryParameters,
            options: _opts(options, isPublic: isPublic),
            cancelToken: cancelToken),
        fromJson: fromJson,
      );

  /// Sends a DELETE request and parses the response using [fromJson].
  Future<Result<T>> delete<T>(
    String path, {
    required FromJson<T> fromJson,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isPublic = false,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeCall(
        () => _dio.delete(path,
            data: data,
            queryParameters: queryParameters,
            options: _opts(options, isPublic: isPublic),
            cancelToken: cancelToken),
        fromJson: fromJson,
      );

  /// Raw request — returns `Map<String, dynamic>`. For legacy/migration use.
  Future<Result<Map<String, dynamic>>> raw(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isPublic = false,
    Options? options,
  }) =>
      _safeCall(
        () => _dio.request(path,
            data: data,
            queryParameters: queryParameters,
            options: _opts(
              (options ?? Options()).copyWith(method: method),
              isPublic: isPublic,
            )),
        fromJson: (j) =>
            j is Map<String, dynamic> ? j : <String, dynamic>{},
      );

  // ═══════════════════════════════════════════════════════════════════════
  // CACHE CONTROL
  // ═══════════════════════════════════════════════════════════════════════

  /// Clear all cached responses.
  void clearCache() => _cacheInterceptor?.clearCache();

  /// Invalidate cache entries matching a path.
  void invalidateCache(String path) => _cacheInterceptor?.invalidate(path);

  // ═══════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════

  /// Call when the app is shutting down or toolkit is no longer needed.
  void dispose() {
    _offlineQueue?.dispose();
    _dio.close();
    _refreshDio.close();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INTERNALS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Result<T>> _safeCall<T>(
    Future<Response> Function() call, {
    required FromJson<T> fromJson,
  }) async {
    try {
      final response = await call();
      final parsed = fromJson(response.data);
      return Success(
        parsed,
        statusCode: response.statusCode,
        raw: response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : null,
      );
    } on DioException catch (e) {
      final error = NetworkError.fromDioException(e);
      _config.onError?.call(error);

      // Queue for offline replay if applicable
      if (error.type == NetworkErrorType.noConnection) {
        _offlineQueue?.enqueue(e.requestOptions);
      }

      return Failure(error);
    } catch (e, st) {
      final error = NetworkError.parsing(e, st);
      _config.onError?.call(error);
      return Failure(error);
    }
  }

  Options _opts(Options? options,
      {required bool isPublic, Map<String, dynamic>? extra}) {
    final base = options ?? Options();
    return base.copyWith(extra: {
      ...?base.extra,
      'isPublic': isPublic,
      ...?extra,
    });
  }
}

/// Create and manage multiple toolkit instances for different API hosts.
///
/// ```dart
/// final toolkits = NetworkToolkitFactory({
///   'main': NetworkToolkitConfig(baseUrl: 'https://api.example.com', ...),
///   'auth': NetworkToolkitConfig(baseUrl: 'https://auth.example.com', ...),
///   'cdn':  NetworkToolkitConfig(baseUrl: 'https://cdn.example.com', ...),
/// });
///
/// final result = await toolkits['main']!.get(...);
/// final authResult = await toolkits['auth']!.post('/login', ...);
/// ```
class NetworkToolkitFactory {
  final Map<String, NetworkToolkit> _instances = {};

  /// Creates toolkit instances from a map of named configurations.
  NetworkToolkitFactory(Map<String, NetworkToolkitConfig> configs) {
    for (final entry in configs.entries) {
      _instances[entry.key] = NetworkToolkit(entry.value);
    }
  }

  /// Returns the toolkit registered with [name], or null if not found.
  NetworkToolkit? operator [](String name) => _instances[name];

  /// Get instance or throw if not found.
  NetworkToolkit get(String name) {
    final instance = _instances[name];
    if (instance == null) {
      throw ArgumentError('No NetworkToolkit registered with name: $name');
    }
    return instance;
  }

  /// Disposes all toolkit instances and clears the registry.
  void dispose() {
    for (final instance in _instances.values) {
      instance.dispose();
    }
    _instances.clear();
  }
}
