import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Structured, pretty debug-only logging.
class PrettyLogInterceptor extends Interceptor {
  final void Function(String)? _logPrint;

  PrettyLogInterceptor({void Function(String)? logPrint})
      : _logPrint = logPrint;

  void _log(String msg) {
    if (!kDebugMode) return;
    (_logPrint ?? debugPrint)(msg);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final retry = options.extra['_retryAttempt'] as int? ?? 0;
    final retryLabel = retry > 0 ? ' (retry #$retry)' : '';
    _log('\u2192 ${options.method} ${options.uri}$retryLabel');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log('\u2190 ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log('\u2717 ${err.response?.statusCode ?? "N/A"} ${err.requestOptions.method} '
        '${err.requestOptions.uri} \u2014 ${err.message}');
    handler.next(err);
  }
}
