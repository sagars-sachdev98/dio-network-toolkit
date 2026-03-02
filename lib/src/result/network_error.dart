import 'package:dio/dio.dart';

enum NetworkErrorType {
  noConnection,
  timeout,
  clientError, // 4xx
  serverError, // 5xx
  unauthorized, // 401/403
  cancelled,
  parsing,
  rateLimited, // 429
  unknown,
}

class NetworkError {
  final NetworkErrorType type;
  final String message;
  final String? userMessage;
  final int? statusCode;
  final Map<String, dynamic>? responseBody;
  final dynamic rawError;
  final StackTrace? stackTrace;

  const NetworkError({
    required this.type,
    required this.message,
    this.userMessage,
    this.statusCode,
    this.responseBody,
    this.rawError,
    this.stackTrace,
  });

  factory NetworkError.fromDioException(DioException e) {
    final type = _classifyDioException(e);
    Map<String, dynamic>? body;
    String? serverMsg;
    try {
      if (e.response?.data is Map) {
        body = Map<String, dynamic>.from(e.response!.data);
        // Common patterns: "message", "error", "error_description", "detail"
        serverMsg = body['message'] as String? ??
            body['error'] as String? ??
            body['error_description'] as String? ??
            body['detail'] as String?;
      }
    } catch (_) {}

    return NetworkError(
      type: type,
      message: e.message ?? 'An unexpected error occurred',
      userMessage: serverMsg ?? _defaultMessage(type),
      statusCode: e.response?.statusCode,
      responseBody: body,
      rawError: e,
    );
  }

  factory NetworkError.parsing(Object error, StackTrace st) => NetworkError(
        type: NetworkErrorType.parsing,
        message: 'Failed to parse response: $error',
        userMessage: 'Something went wrong. Please try again.',
        stackTrace: st,
        rawError: error,
      );

  factory NetworkError.noConnection() => const NetworkError(
        type: NetworkErrorType.noConnection,
        message: 'No internet connection',
        userMessage: 'No internet connection. Please check your network.',
      );

  static NetworkErrorType _classifyDioException(DioException e) =>
      switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          NetworkErrorType.timeout,
        DioExceptionType.cancel => NetworkErrorType.cancelled,
        DioExceptionType.connectionError => NetworkErrorType.noConnection,
        DioExceptionType.badResponse =>
          _classifyStatusCode(e.response?.statusCode),
        _ => NetworkErrorType.unknown,
      };

  static NetworkErrorType _classifyStatusCode(int? code) {
    if (code == null) return NetworkErrorType.unknown;
    if (code == 401 || code == 403) return NetworkErrorType.unauthorized;
    if (code == 429) return NetworkErrorType.rateLimited;
    if (code >= 400 && code < 500) return NetworkErrorType.clientError;
    if (code >= 500) return NetworkErrorType.serverError;
    return NetworkErrorType.unknown;
  }

  static String _defaultMessage(NetworkErrorType type) => switch (type) {
        NetworkErrorType.noConnection =>
          'No internet connection. Please check your network.',
        NetworkErrorType.timeout => 'Request timed out. Please try again.',
        NetworkErrorType.unauthorized =>
          'Session expired. Please log in again.',
        NetworkErrorType.serverError =>
          'Server error. Please try again later.',
        NetworkErrorType.clientError =>
          'Invalid request. Please check your input.',
        NetworkErrorType.cancelled => 'Request was cancelled.',
        NetworkErrorType.rateLimited =>
          'Too many requests. Please wait a moment.',
        NetworkErrorType.parsing =>
          'Something went wrong. Please try again.',
        NetworkErrorType.unknown =>
          'Something went wrong. Please try again.',
      };

  /// Check if this error is retryable by the user (show retry button)
  bool get isRetryable => switch (type) {
        NetworkErrorType.noConnection ||
        NetworkErrorType.timeout ||
        NetworkErrorType.serverError ||
        NetworkErrorType.rateLimited =>
          true,
        _ => false,
      };

  @override
  String toString() =>
      'NetworkError(type: $type, statusCode: $statusCode, message: $message)';
}
