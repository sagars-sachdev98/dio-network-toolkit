import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';
import 'test_helpers.dart';

void main() {
  group('NetworkError.fromDioException', () {
    test('classifies connectionTimeout as timeout', () {
      final e = makeDioException(type: DioExceptionType.connectionTimeout);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.timeout);
      expect(error.isRetryable, isTrue);
    });

    test('classifies sendTimeout as timeout', () {
      final e = makeDioException(type: DioExceptionType.sendTimeout);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.timeout);
    });

    test('classifies receiveTimeout as timeout', () {
      final e = makeDioException(type: DioExceptionType.receiveTimeout);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.timeout);
    });

    test('classifies cancel as cancelled', () {
      final e = makeDioException(type: DioExceptionType.cancel);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.cancelled);
      expect(error.isRetryable, isFalse);
    });

    test('classifies connectionError as noConnection', () {
      final e = makeDioException(type: DioExceptionType.connectionError);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.noConnection);
      expect(error.isRetryable, isTrue);
    });

    test('classifies 401 as unauthorized', () {
      final e = makeDioException(statusCode: 401);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.unauthorized);
      expect(error.statusCode, 401);
      expect(error.isRetryable, isFalse);
    });

    test('classifies 403 as unauthorized', () {
      final e = makeDioException(statusCode: 403);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.unauthorized);
    });

    test('classifies 429 as rateLimited', () {
      final e = makeDioException(statusCode: 429);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.rateLimited);
      expect(error.isRetryable, isTrue);
    });

    test('classifies 400 as clientError', () {
      final e = makeDioException(statusCode: 400);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.clientError);
      expect(error.isRetryable, isFalse);
    });

    test('classifies 404 as clientError', () {
      final e = makeDioException(statusCode: 404);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.clientError);
    });

    test('classifies 500 as serverError', () {
      final e = makeDioException(statusCode: 500);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.serverError);
      expect(error.isRetryable, isTrue);
    });

    test('classifies 503 as serverError', () {
      final e = makeDioException(statusCode: 503);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.serverError);
    });

    test('extracts server message from body', () {
      final e = makeDioException(
        statusCode: 400,
        data: {'message': 'Invalid email'},
      );
      final error = NetworkError.fromDioException(e);
      expect(error.userMessage, 'Invalid email');
      expect(error.responseBody, containsPair('message', 'Invalid email'));
    });

    test('extracts error_description from body', () {
      final e = makeDioException(
        statusCode: 400,
        data: {'error_description': 'Token expired'},
      );
      final error = NetworkError.fromDioException(e);
      expect(error.userMessage, 'Token expired');
    });

    test('falls back to default message when body has no message field', () {
      final e = makeDioException(statusCode: 500, data: {'code': 'ERR'});
      final error = NetworkError.fromDioException(e);
      expect(error.userMessage, contains('Server error'));
    });

    test('unknown type for unrecognized DioExceptionType', () {
      final e = makeDioException(type: DioExceptionType.badCertificate);
      final error = NetworkError.fromDioException(e);
      expect(error.type, NetworkErrorType.unknown);
    });
  });

  group('NetworkError.parsing', () {
    test('creates parsing error', () {
      final error = NetworkError.parsing(
          FormatException('bad json'), StackTrace.current);
      expect(error.type, NetworkErrorType.parsing);
      expect(error.message, contains('bad json'));
      expect(error.isRetryable, isFalse);
    });
  });

  group('NetworkError.noConnection', () {
    test('creates noConnection error', () {
      final error = NetworkError.noConnection();
      expect(error.type, NetworkErrorType.noConnection);
      expect(error.userMessage, contains('internet'));
    });
  });

  group('toString', () {
    test('includes type and message', () {
      final error = NetworkError.noConnection();
      expect(error.toString(), contains('noConnection'));
    });
  });
}
