import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';

void main() {
  final error = NetworkError.noConnection();

  group('mapSuccess', () {
    test('transforms success data', () {
      const Result<int> result = Success(5);
      final mapped = result.mapSuccess((d) => d * 2);
      expect(mapped.dataOrNull, 10);
    });

    test('passes through failure', () {
      final Result<int> result = Failure(error);
      final mapped = result.mapSuccess((d) => d * 2);
      expect(mapped.isFailure, isTrue);
    });

    test('preserves statusCode and raw on success', () {
      const Result<int> result = Success(5, statusCode: 200, raw: {'v': 5});
      final mapped = result.mapSuccess((d) => d.toString());
      expect((mapped as Success<String>).statusCode, 200);
      expect(mapped.raw, {'v': 5});
    });
  });

  group('flatMap', () {
    test('chains success', () async {
      const Result<int> result = Success(5);
      final chained = await result.flatMap((d) async => Success(d * 3));
      expect(chained.dataOrNull, 15);
    });

    test('passes through failure', () async {
      final Result<int> result = Failure(error);
      final chained = await result.flatMap((d) async => Success(d * 3));
      expect(chained.isFailure, isTrue);
    });
  });

  group('dataOrThrow', () {
    test('returns data on success', () {
      const Result<int> result = Success(42);
      expect(result.dataOrThrow, 42);
    });

    test('throws NetworkError on failure (not Exception)', () {
      final Result<int> result = Failure(error);
      expect(
        () => result.dataOrThrow,
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('dataOr', () {
    test('returns data on success', () {
      const Result<int> result = Success(42);
      expect(result.dataOr(0), 42);
    });

    test('returns fallback on failure', () {
      final Result<int> result = Failure(error);
      expect(result.dataOr(0), 0);
    });
  });

  group('onSuccess', () {
    test('executes action on success', () {
      int? captured;
      const Result<int> result = Success(7);
      final returned = result.onSuccess((d) => captured = d);
      expect(captured, 7);
      expect(identical(returned, result), isTrue);
    });

    test('does nothing on failure', () {
      int? captured;
      final Result<int> result = Failure(error);
      result.onSuccess((d) => captured = d);
      expect(captured, isNull);
    });
  });

  group('onFailure', () {
    test('executes action on failure', () {
      NetworkError? captured;
      final Result<int> result = Failure(error);
      final returned = result.onFailure((e) => captured = e);
      expect(captured, error);
      expect(identical(returned, result), isTrue);
    });

    test('does nothing on success', () {
      NetworkError? captured;
      const Result<int> result = Success(7);
      result.onFailure((e) => captured = e);
      expect(captured, isNull);
    });
  });
}
