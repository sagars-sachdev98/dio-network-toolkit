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
  const Result();

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

  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>() => null,
      };

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
}

final class Success<T> extends Result<T> {
  final T data;
  final int? statusCode;
  final Map<String, dynamic>? raw;

  const Success(this.data, {this.statusCode, this.raw});

  @override
  String toString() => 'Success(statusCode: $statusCode, data: $data)';
}

final class Failure<T> extends Result<T> {
  final NetworkError error;

  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';
}
