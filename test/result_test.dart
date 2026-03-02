import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';

void main() {
  group('Success', () {
    test('holds data and optional fields', () {
      const result = Success(42, statusCode: 200, raw: {'id': 42});
      expect(result.data, 42);
      expect(result.statusCode, 200);
      expect(result.raw, {'id': 42});
    });

    test('isSuccess / isFailure', () {
      const Result<int> result = Success(1);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('dataOrNull returns data', () {
      const Result<String> result = Success('hello');
      expect(result.dataOrNull, 'hello');
    });

    test('toString', () {
      const result = Success(42, statusCode: 200);
      expect(result.toString(), contains('Success'));
      expect(result.toString(), contains('200'));
    });
  });

  group('Failure', () {
    final error = NetworkError.noConnection();

    test('holds error', () {
      final result = Failure<int>(error);
      expect(result.error, error);
    });

    test('isSuccess / isFailure', () {
      final Result<int> result = Failure(error);
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
    });

    test('dataOrNull returns null', () {
      final Result<String> result = Failure(error);
      expect(result.dataOrNull, isNull);
    });

    test('toString', () {
      final result = Failure<int>(error);
      expect(result.toString(), contains('Failure'));
    });
  });

  group('when()', () {
    test('calls success branch on Success', () {
      const Result<int> result = Success(10, statusCode: 200);
      final value = result.when(
        success: (data, code, raw) => 'data=$data,code=$code',
        failure: (error) => 'fail',
      );
      expect(value, 'data=10,code=200');
    });

    test('calls failure branch on Failure', () {
      final Result<int> result = Failure(NetworkError.noConnection());
      final value = result.when(
        success: (data, code, raw) => 'ok',
        failure: (error) => 'error=${error.type}',
      );
      expect(value, 'error=NetworkErrorType.noConnection');
    });
  });

  group('pattern matching', () {
    test('switch works with Success', () {
      const Result<int> result = Success(5);
      final msg = switch (result) {
        Success(:final data) => 'got $data',
        Failure(:final error) => 'fail: ${error.type}',
      };
      expect(msg, 'got 5');
    });

    test('switch works with Failure', () {
      final Result<int> result = Failure(NetworkError.noConnection());
      final msg = switch (result) {
        Success(:final data) => 'got $data',
        Failure(:final error) => 'fail: ${error.type}',
      };
      expect(msg, contains('noConnection'));
    });
  });
}
