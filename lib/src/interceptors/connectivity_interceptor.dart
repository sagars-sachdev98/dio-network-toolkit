import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

/// Checks connectivity BEFORE sending request. Fails fast with clear error.
class ConnectivityInterceptor extends Interceptor {
  final Connectivity _connectivity;

  /// Creates a [ConnectivityInterceptor] with an optional [Connectivity] instance.
  ConnectivityInterceptor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'No internet connection',
      ));
    } else {
      handler.next(options);
    }
  }
}
