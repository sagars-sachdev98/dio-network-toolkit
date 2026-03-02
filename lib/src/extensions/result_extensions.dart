import '../result/result.dart';
import '../result/network_error.dart';

extension ResultExtensions<T> on Result<T> {
  /// Transform the success data.
  Result<R> mapSuccess<R>(R Function(T data) transform) => switch (this) {
        Success<T>(:final data, :final statusCode, :final raw) =>
          Success(transform(data), statusCode: statusCode, raw: raw),
        Failure<T>(:final error) => Failure(error),
      };

  /// Chain another async Result operation.
  Future<Result<R>> flatMap<R>(
          Future<Result<R>> Function(T data) transform) async =>
      switch (this) {
        Success<T>(:final data) => await transform(data),
        Failure<T>(:final error) => Failure(error),
      };

  /// Get data or throw — use only when you're sure it's a success.
  /// Throws the [NetworkError] directly so callers can catch it.
  T get dataOrThrow => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>(:final error) => throw error,
      };

  /// Get data or return a fallback.
  T dataOr(T fallback) => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>() => fallback,
      };

  /// Execute side effect on success without transforming.
  Result<T> onSuccess(void Function(T data) action) {
    if (this case Success<T>(:final data)) action(data);
    return this;
  }

  /// Execute side effect on failure without transforming.
  Result<T> onFailure(void Function(NetworkError error) action) {
    if (this case Failure<T>(:final error)) action(error);
    return this;
  }
}
