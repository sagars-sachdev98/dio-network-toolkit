import 'package:dio/dio.dart';
import '../result/result.dart';
import '../result/network_error.dart';

typedef ProgressCallback = void Function(int sent, int total, double percent);

/// Simplified file upload with progress tracking.
///
/// ```dart
/// final result = await toolkit.upload.file(
///   '/documents/upload',
///   filePath: '/path/to/document.pdf',
///   field: 'file',
///   extraFields: {'category': 'invoice'},
///   onProgress: (sent, total, percent) {
///     emit(UploadProgress(percent));
///   },
/// );
/// ```
class UploadManager {
  final Dio _dio;

  UploadManager(this._dio);

  /// Upload a single file with progress.
  Future<Result<T>> file<T>(
    String path, {
    required String filePath,
    required T Function(dynamic json) fromJson,
    String field = 'file',
    String? fileName,
    Map<String, dynamic>? extraFields,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final formData = FormData.fromMap({
        field: await MultipartFile.fromFile(filePath, filename: fileName),
        ...?extraFields,
      });

      final response = await _dio.post(
        path,
        data: formData,
        cancelToken: cancelToken,
        options: Options(headers: headers),
        onSendProgress: onProgress != null
            ? (sent, total) {
                final percent = total > 0 ? (sent / total * 100) : 0.0;
                onProgress(sent, total, percent);
              }
            : null,
      );

      return Success(fromJson(response.data), statusCode: response.statusCode);
    } on DioException catch (e) {
      return Failure(NetworkError.fromDioException(e));
    } catch (e, st) {
      return Failure(NetworkError.parsing(e, st));
    }
  }

  /// Upload multiple files.
  Future<Result<T>> multiFile<T>(
    String path, {
    required Map<String, String> filePaths, // field → path
    required T Function(dynamic json) fromJson,
    Map<String, dynamic>? extraFields,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final map = <String, dynamic>{...?extraFields};
      for (final entry in filePaths.entries) {
        map[entry.key] = await MultipartFile.fromFile(entry.value);
      }

      final response = await _dio.post(
        path,
        data: FormData.fromMap(map),
        cancelToken: cancelToken,
        onSendProgress: onProgress != null
            ? (s, t) => onProgress(s, t, t > 0 ? s / t * 100 : 0)
            : null,
      );

      return Success(fromJson(response.data), statusCode: response.statusCode);
    } on DioException catch (e) {
      return Failure(NetworkError.fromDioException(e));
    } catch (e, st) {
      return Failure(NetworkError.parsing(e, st));
    }
  }

  /// Upload bytes directly (e.g., camera capture, canvas export).
  Future<Result<T>> bytes<T>(
    String path, {
    required List<int> data,
    required T Function(dynamic json) fromJson,
    required String fileName,
    String field = 'file',
    DioMediaType? contentType,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        field: MultipartFile.fromBytes(data,
            filename: fileName, contentType: contentType),
      });

      final response = await _dio.post(
        path,
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: onProgress != null
            ? (s, t) => onProgress(s, t, t > 0 ? s / t * 100 : 0)
            : null,
      );

      return Success(fromJson(response.data), statusCode: response.statusCode);
    } on DioException catch (e) {
      return Failure(NetworkError.fromDioException(e));
    } catch (e, st) {
      return Failure(NetworkError.parsing(e, st));
    }
  }
}
