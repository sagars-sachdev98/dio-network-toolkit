import 'dart:async';
import 'package:dio/dio.dart';
import '../core/config.dart';

/// Handles token injection + automatic refresh with request queuing.
///
/// When a 401 is received:
/// 1. The first request creates a Completer and triggers refresh
/// 2. Subsequent 401s await the same Completer (no double-refresh)
/// 3. All waiters retry with the new token
/// 4. If refresh fails, calls onTokenExpired
class AuthInterceptor extends QueuedInterceptor {
  final AuthConfig _config;
  final Dio _refreshDio;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({required AuthConfig config, required Dio refreshDio})
      : _config = config,
        _refreshDio = refreshDio;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['isPublic'] == true) return handler.next(options);

    final token = await _config.tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers[_config.headerKey] = '${_config.tokenPrefix}$token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    if (statusCode == null ||
        !_config.unauthorizedCodes.contains(statusCode) ||
        _config.refreshToken == null ||
        err.requestOptions.extra['isPublic'] == true ||
        err.requestOptions.extra['_isRetryAfterRefresh'] == true) {
      return handler.next(err);
    }

    try {
      String? newToken;

      if (_refreshCompleter != null) {
        // Another request is already refreshing — wait for it
        newToken = await _refreshCompleter!.future;
      } else {
        // First 401 — trigger the refresh
        _refreshCompleter = Completer<String?>();
        try {
          newToken = await _config.refreshToken!(_refreshDio);
          _refreshCompleter!.complete(newToken);
        } catch (_) {
          // Complete with null so waiting requests see "no token"
          _refreshCompleter!.complete(null);
          newToken = null;
        } finally {
          _refreshCompleter = null;
        }
      }

      if (newToken == null || newToken.isEmpty) {
        _config.onTokenExpired?.call();
        return handler.next(err);
      }

      // Retry original request with the new token
      final opts = err.requestOptions;
      opts.headers[_config.headerKey] = '${_config.tokenPrefix}$newToken';
      opts.extra['_isRetryAfterRefresh'] = true;

      final response = await _refreshDio.fetch(opts);
      return handler.resolve(response);
    } catch (_) {
      _config.onTokenExpired?.call();
      return handler.next(err);
    }
  }
}
