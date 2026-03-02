import 'dart:io';
import 'package:dio/dio.dart';
import '../core/config.dart';

/// Smart retry with exponential backoff + jitter.
///
/// Retries only on transient errors (timeouts, 5xx, connection errors).
/// Respects idempotency — by default, POST is NOT retried (configurable).
/// Includes Retry-After header support for 429 responses.
class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final RetryConfig _config;

  RetryInterceptor({required Dio dio, required RetryConfig config})
      : _dio = dio,
        _config = config;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['_retryAttempt'] as int?) ?? 0;

    if (attempt >= _config.maxAttempts || !_shouldRetry(err, attempt)) {
      return handler.next(err);
    }

    // Respect Retry-After header for 429
    Duration delay;
    final retryAfter = err.response?.headers.value('retry-after');
    if (retryAfter != null && err.response?.statusCode == 429) {
      final seconds = int.tryParse(retryAfter);
      delay = seconds != null
          ? Duration(seconds: seconds)
          : _config.delayForAttempt(attempt);
    } else {
      delay = _config.delayForAttempt(attempt);
    }

    await Future.delayed(delay);

    err.requestOptions.extra['_retryAttempt'] = attempt + 1;

    try {
      final response = await _dio.fetch(err.requestOptions);
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      } else {
        handler
            .next(DioException(requestOptions: err.requestOptions, error: e));
      }
    }
  }

  bool _shouldRetry(DioException err, int attempt) {
    // Custom evaluator takes priority
    if (_config.retryWhen != null) return _config.retryWhen!(err, attempt);

    // Method check
    if (_config.retryableMethods != null) {
      if (!_config.retryableMethods!
          .contains(err.requestOptions.method.toUpperCase())) {
        return false;
      }
    }

    // Per-request disable
    if (err.requestOptions.extra['noRetry'] == true) return false;

    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        _config.retryOnTimeout,
      DioExceptionType.connectionError => _config.retryOnConnectionError,
      DioExceptionType.badResponse =>
        _config.retryableStatusCodes.contains(err.response?.statusCode),
      DioExceptionType.unknown => err.error is SocketException,
      _ => false,
    };
  }
}
