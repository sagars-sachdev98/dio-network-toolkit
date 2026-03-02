import 'dart:async';
import 'package:dio/dio.dart';

/// Deduplicates identical GET requests that are in-flight simultaneously.
///
/// Problem: 3 widgets all call `GET /user/profile` at the same time.
/// Without dedup: 3 network requests.
/// With dedup: 1 network request, 3 widgets get the same response.
class DedupInterceptor extends Interceptor {
  final _pending = <String, Completer<Response>>{};

  String _key(RequestOptions opts) => '${opts.method}:${opts.uri}';

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Only dedup GET requests
    if (options.method.toUpperCase() != 'GET') return handler.next(options);
    if (options.extra['noDedup'] == true) return handler.next(options);

    final key = _key(options);

    if (_pending.containsKey(key)) {
      // An identical request is already in-flight — wait for it
      try {
        final response = await _pending[key]!.future;
        return handler.resolve(Response(
          requestOptions: options,
          data: response.data,
          statusCode: response.statusCode,
          headers: response.headers,
        ));
      } catch (e) {
        return handler.reject(e is DioException
            ? e
            : DioException(requestOptions: options, error: e));
      }
    }

    // First request for this key — mark as pending
    _pending[key] = Completer<Response>();
    // Suppress unhandled error when no duplicate request is waiting
    _pending[key]!.future.ignore();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = _key(response.requestOptions);
    _pending[key]?.complete(response);
    _pending.remove(key);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = _key(err.requestOptions);
    _pending[key]?.completeError(err);
    _pending.remove(key);
    handler.next(err);
  }
}
