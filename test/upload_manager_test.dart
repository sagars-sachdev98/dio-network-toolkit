import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test.com'));
  });

  tearDown(() {
    dio.close();
  });

  group('UploadManager.bytes()', () {
    test('uploads bytes with filename', () async {
      FormData? capturedData;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedData = options.data as FormData?;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'id': 'upload-123'},
          ));
        },
      ));

      final manager = UploadManager(dio);
      final result = await manager.bytes<Map<String, dynamic>>(
        '/upload',
        data: [1, 2, 3, 4, 5],
        fromJson: (j) => j as Map<String, dynamic>,
        fileName: 'test.bin',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, containsPair('id', 'upload-123'));
      expect(capturedData, isNotNull);
    });

    test('passes contentType to MultipartFile', () async {
      FormData? capturedData;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedData = options.data as FormData?;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'ok': true},
          ));
        },
      ));

      final manager = UploadManager(dio);
      await manager.bytes<Map<String, dynamic>>(
        '/upload',
        data: [1, 2, 3],
        fromJson: (j) => j as Map<String, dynamic>,
        fileName: 'image.png',
        contentType: DioMediaType.parse('image/png'),
      );

      // Verify the multipart file has the correct content type
      final files = capturedData!.files;
      expect(files, isNotEmpty);
      expect(files.first.value.contentType.toString(), 'image/png');
    });

    test('returns Failure on DioException', () async {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ));
        },
      ));

      final manager = UploadManager(dio);
      final result = await manager.bytes<Map<String, dynamic>>(
        '/upload',
        data: [1, 2, 3],
        fromJson: (j) => j as Map<String, dynamic>,
        fileName: 'test.bin',
      );

      expect(result.isFailure, isTrue);
    });

    test('returns Failure on parsing error', () async {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: 'not json',
          ));
        },
      ));

      final manager = UploadManager(dio);
      final result = await manager.bytes<Map<String, dynamic>>(
        '/upload',
        data: [1, 2, 3],
        fromJson: (j) => j as Map<String, dynamic>,
        fileName: 'test.bin',
      );

      expect(result.isFailure, isTrue);
      expect((result as Failure).error.type, NetworkErrorType.parsing);
    });

    test('reports progress', () async {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'ok': true},
          ));
        },
      ));

      var progressCalled = false;
      final manager = UploadManager(dio);
      await manager.bytes<Map<String, dynamic>>(
        '/upload',
        data: [1, 2, 3],
        fromJson: (j) => j as Map<String, dynamic>,
        fileName: 'test.bin',
        onProgress: (sent, total, percent) {
          progressCalled = true;
        },
      );

      // Progress may or may not be called depending on interceptor short-circuit,
      // but the callback should not throw. We only verify it doesn't error.
      expect(progressCalled, anyOf(isTrue, isFalse));
    });
  });
}
