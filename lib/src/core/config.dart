import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../result/network_error.dart';

// ── Auth ────────────────────────────────────────────────────────────────

/// JWT / Bearer token handling with optional refresh.
///
/// Works with any storage: SharedPreferences, FlutterSecureStorage,
/// Hive, or your own CookieService.
class AuthConfig {
  /// Returns the current access token. Called before every private request.
  final Future<String?> Function() tokenProvider;

  /// Called on 401. Return a new token, or null to trigger [onTokenExpired].
  /// Receives a CLEAN Dio (no auth interceptor) to avoid infinite loops.
  final Future<String?> Function(Dio dio)? refreshToken;

  /// Called when refresh returns null or throws. Use to force-logout.
  final void Function()? onTokenExpired;

  /// Header key. Default: 'Authorization'
  final String headerKey;

  /// Token prefix. Default: 'Bearer '
  final String tokenPrefix;

  /// HTTP status codes considered as "unauthorized". Default: {401}
  final Set<int> unauthorizedCodes;

  /// Creates an auth configuration for token injection and refresh.
  const AuthConfig({
    required this.tokenProvider,
    this.refreshToken,
    this.onTokenExpired,
    this.headerKey = 'Authorization',
    this.tokenPrefix = 'Bearer ',
    this.unauthorizedCodes = const {401},
  });
}

// ── Retry ───────────────────────────────────────────────────────────────

/// Configuration for automatic request retries with exponential backoff.
class RetryConfig {
  /// Maximum number of retry attempts before giving up.
  final int maxAttempts;

  /// Base delay between retries, doubled on each attempt.
  final Duration baseDelay;

  /// Maximum delay cap to prevent excessively long waits.
  final Duration maxDelay;

  /// Whether to add random jitter to prevent thundering herd.
  final bool useJitter;

  /// HTTP status codes that trigger a retry.
  final Set<int> retryableStatusCodes;

  /// Whether to retry on timeout errors.
  final bool retryOnTimeout;

  /// Whether to retry on connection errors.
  final bool retryOnConnectionError;

  /// Methods safe to retry. null = all methods.
  /// Default = only idempotent methods.
  final Set<String>? retryableMethods;

  /// Custom evaluator. If provided, overrides all other checks.
  final bool Function(DioException error, int attempt)? retryWhen;

  /// Creates a retry configuration.
  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.useJitter = true,
    this.retryableStatusCodes = const {500, 502, 503, 504, 408, 429},
    this.retryOnTimeout = true,
    this.retryOnConnectionError = true,
    this.retryableMethods = const {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'},
    this.retryWhen,
  });

  /// Disables retries entirely.
  static const none = RetryConfig(maxAttempts: 0);

  /// Aggressive retry preset: 5 attempts, 500ms base delay, all methods.
  static const aggressive = RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(milliseconds: 500),
    retryableMethods: null,
  );

  /// Calculates the delay for a given retry [attempt] using exponential backoff.
  Duration delayForAttempt(int attempt) {
    final exp = baseDelay * math.pow(2, math.min(attempt, 10)).toInt();
    final capped = exp > maxDelay ? maxDelay : exp;
    if (!useJitter) return capped;
    return Duration(
        milliseconds: math.Random().nextInt(capped.inMilliseconds + 1));
  }
}

// ── Cache ───────────────────────────────────────────────────────────────

/// Strategy for how the cache interceptor serves and refreshes data.
enum CacheStrategy {
  /// Always fetch network first, cache result for fallback.
  networkFirst,

  /// Return cache if fresh, otherwise fetch from network.
  cacheFirst,

  /// Return stale cache immediately AND refresh in background.
  staleWhileRevalidate,
}

/// Configuration for the in-memory GET response cache.
class CacheConfig {
  /// The caching strategy to use.
  final CacheStrategy strategy;

  /// How long cached responses remain fresh.
  final Duration maxAge;

  /// Maximum number of cached entries before eviction.
  final int maxEntries;

  /// Paths to exclude from caching (regex patterns).
  final List<RegExp> excludePaths;

  /// Creates a cache configuration.
  const CacheConfig({
    this.strategy = CacheStrategy.networkFirst,
    this.maxAge = const Duration(minutes: 5),
    this.maxEntries = 100,
    this.excludePaths = const [],
  });

  /// Disables caching entirely.
  static const none = CacheConfig(maxAge: Duration.zero);
}

// ── Offline Queue ──────────────────────────────────────────────────────

/// Configuration for offline request queuing and replay.
class OfflineQueueConfig {
  /// Enable offline request queuing for mutation requests.
  final bool enabled;

  /// Maximum queued requests. Default: 50.
  final int maxQueueSize;

  /// Methods to queue when offline. Default: POST, PUT, PATCH, DELETE.
  final Set<String> queueableMethods;

  /// Called when queued requests are replayed.
  final void Function(int successCount, int failCount)? onReplayComplete;

  /// Creates an offline queue configuration.
  const OfflineQueueConfig({
    this.enabled = true,
    this.maxQueueSize = 50,
    this.queueableMethods = const {'POST', 'PUT', 'PATCH', 'DELETE'},
    this.onReplayComplete,
  });
}

// ── Main Config ─────────────────────────────────────────────────────────

/// Top-level configuration for [NetworkToolkit].
class NetworkToolkitConfig {
  /// Base URL for all API requests.
  final String baseUrl;

  /// Authentication configuration. Omit for public-only APIs.
  final AuthConfig? auth;

  /// Retry configuration for transient failures.
  final RetryConfig retry;

  /// Cache configuration. Omit to disable caching.
  final CacheConfig? cache;

  /// Offline queue configuration. Omit to disable offline queuing.
  final OfflineQueueConfig? offlineQueue;

  /// Connection timeout for each request.
  final Duration connectTimeout;

  /// Receive timeout for each request.
  final Duration receiveTimeout;

  /// Send timeout for each request.
  final Duration sendTimeout;

  /// Default headers applied to every request.
  final Map<String, dynamic> defaultHeaders;

  /// Whether to enable debug logging in debug mode.
  final bool enableLogging;

  /// Custom log printer. Defaults to debugPrint.
  final void Function(String message)? logPrinter;

  /// Global error callback. Runs on EVERY error before Result is returned.
  /// Use for: toast/snackbar, analytics, crash reporting.
  final void Function(NetworkError error)? onError;

  /// Additional Dio interceptors you want to add.
  final List<Interceptor> extraInterceptors;

  /// Creates the main configuration for [NetworkToolkit].
  NetworkToolkitConfig({
    required this.baseUrl,
    this.auth,
    this.retry = const RetryConfig(),
    this.cache,
    this.offlineQueue,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.defaultHeaders = const {},
    this.enableLogging = true,
    this.logPrinter,
    this.onError,
    this.extraInterceptors = const [],
  }) {
    final uri = Uri.tryParse(baseUrl);
    if (baseUrl.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      throw ArgumentError.value(
          baseUrl, 'baseUrl', 'Must be a valid URL with scheme and host');
    }
  }
}
