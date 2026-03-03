import 'network_error.dart';

/// Sealed result type — every network call returns this. No nulls, no exceptions.
///
/// ```dart
/// final result = await toolkit.get<User>('/me', fromJson: User.fromJson);
///
/// // Pattern match (Dart 3):
/// switch (result) {
///   case Success(:final data): print(data.name);
///   case Failure(:final error): print(error.userMessage);
/// }
///
/// // Or use callbacks:
/// result.when(
///   success: (data, code, raw) => emit(Loaded(data)),
///   failure: (error) => emit(Error(error.userMessage)),
/// );
/// ```
sealed class Result<T> {
  /// Base constructor for [Result].
  const Result();

  /// Callback-style handler for both success and failure cases.
  R when<R>({
    required R Function(T data, int? statusCode, Map<String, dynamic>? raw)
        success,
    required R Function(NetworkError error) failure,
  }) =>
      switch (this) {
        Success<T>(:final data, :final statusCode, :final raw) =>
          success(data, statusCode, raw),
        Failure<T>(:final error) => failure(error),
      };

  /// Returns the data if [Success], or null if [Failure].
  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>() => null,
      };

  /// Whether this result is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Whether this result is a [Failure].
  bool get isFailure => this is Failure<T>;
}

/// A successful network response containing parsed [data].
final class Success<T> extends Result<T> {
  /// The parsed response data.
  final T data;

  /// The HTTP status code from the response.
  final int? statusCode;

  /// The raw response body as a map, if available.
  final Map<String, dynamic>? raw;

  /// Creates a successful result with the given [data].
  const Success(this.data, {this.statusCode, this.raw});

  @override
  String toString() => 'Success(statusCode: $statusCode, data: $data)';
}

/// A failed network response containing an [error].
final class Failure<T> extends Result<T> {
  /// The network error that caused the failure.
  final NetworkError error;

  /// Creates a failure result with the given [error].
  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';
}
