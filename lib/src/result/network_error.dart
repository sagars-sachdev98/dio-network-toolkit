import 'package:dio/dio.dart';

/// Classification of network errors for handling and display.
enum NetworkErrorType {
  /// Device has no internet connection.
  noConnection,

  /// Request timed out (connect, send, or receive).
  timeout,

  /// HTTP 4xx client error (excluding 401/403/429).
  clientError,

  /// HTTP 5xx server error.
  serverError,

  /// HTTP 401 or 403 — authentication/authorization failure.
  unauthorized,

  /// Request was cancelled via [CancelToken].
  cancelled,

  /// Response could not be parsed into the expected type.
  parsing,

  /// HTTP 429 — too many requests.
  rateLimited,

  /// Unclassified error.
  unknown,
}

/// Structured error from a network request with type, message, and metadata.
class NetworkError {
  /// The classified error type.
  final NetworkErrorType type;

  /// Technical error message for logging.
  final String message;

  /// Human-readable message suitable for displaying to users.
  final String? userMessage;

  /// HTTP status code, if available.
  final int? statusCode;

  /// Parsed response body, if available.
  final Map<String, dynamic>? responseBody;

  /// The original error object.
  final dynamic rawError;

  /// Stack trace from parsing errors.
  final StackTrace? stackTrace;

  /// Creates a [NetworkError] with the given properties.
  const NetworkError({
    required this.type,
    required this.message,
    this.userMessage,
    this.statusCode,
    this.responseBody,
    this.rawError,
    this.stackTrace,
  });

  /// Creates a [NetworkError] from a [DioException], classifying the error type
  /// and extracting any server-provided message from the response body.
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

  /// Creates a [NetworkError] for response parsing failures.
  factory NetworkError.parsing(Object error, StackTrace st) => NetworkError(
        type: NetworkErrorType.parsing,
        message: 'Failed to parse response: $error',
        userMessage: 'Something went wrong. Please try again.',
        stackTrace: st,
        rawError: error,
      );

  /// Creates a [NetworkError] for no internet connection.
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

  /// Whether this error is retryable by the user (show retry button).
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
