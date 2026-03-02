import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([Connectivity])
import 'offline_request_queue_test.mocks.dart';

void main() {
  late MockConnectivity mockConnectivity;
  late StreamController<List<ConnectivityResult>> connectivityController;
  late Dio dio;

  setUp(() {
    mockConnectivity = MockConnectivity();
    connectivityController = StreamController<List<ConnectivityResult>>();
    when(mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
    when(mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    dio = Dio(BaseOptions(baseUrl: 'https://api.test.com'));
  });

  tearDown(() {
    connectivityController.close();
    dio.close();
  });

  group('OfflineRequestQueue', () {
    test('enqueues request', () {
      final queue = OfflineRequestQueue(
        dio: dio,
        config: const OfflineQueueConfig(),
        connectivity: mockConnectivity,
      );

      final opts = RequestOptions(path: '/order', method: 'POST');
      final result = queue.enqueue(opts);

      expect(result, isTrue);
      expect(queue.queueLength, 1);
      expect(queue.isEmpty, isFalse);

      queue.dispose();
    });

    test('rejects non-queueable method (GET)', () {
      final queue = OfflineRequestQueue(
        dio: dio,
        config: const OfflineQueueConfig(),
        connectivity: mockConnectivity,
      );

      final opts = RequestOptions(path: '/data', method: 'GET');
      final result = queue.enqueue(opts);

      expect(result, isFalse);
      expect(queue.queueLength, 0);

      queue.dispose();
    });

    test('respects maxQueueSize', () {
      final queue = OfflineRequestQueue(
        dio: dio,
        config: const OfflineQueueConfig(maxQueueSize: 2),
        connectivity: mockConnectivity,
      );

      queue.enqueue(RequestOptions(path: '/a', method: 'POST'));
      queue.enqueue(RequestOptions(path: '/b', method: 'POST'));
      final result = queue.enqueue(RequestOptions(path: '/c', method: 'POST'));

      expect(result, isFalse);
      expect(queue.queueLength, 2);

      queue.dispose();
    });

    test('replays on connectivity restored', () async {
      int replayedCount = 0;
      int successCount = 0;
      int failCount = 0;

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          replayedCount++;
          handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: 'ok'));
        },
      ));

      final queue = OfflineRequestQueue(
        dio: dio,
        config: OfflineQueueConfig(
          onReplayComplete: (s, f) {
            successCount = s;
            failCount = f;
          },
        ),
        connectivity: mockConnectivity,
      );

      queue.enqueue(RequestOptions(path: '/a', method: 'POST'));
      queue.enqueue(RequestOptions(path: '/b', method: 'PUT'));

      // Simulate connectivity restored
      connectivityController.add([ConnectivityResult.wifi]);

      // Wait for replay
      await Future.delayed(const Duration(milliseconds: 100));

      expect(replayedCount, 2);
      expect(successCount, 2);
      expect(failCount, 0);
      expect(queue.isEmpty, isTrue);

      queue.dispose();
    });

    test('reports failures in callback', () async {
      int successCount = 0;
      int failCount = 0;

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ));
        },
      ));

      final queue = OfflineRequestQueue(
        dio: dio,
        config: OfflineQueueConfig(
          onReplayComplete: (s, f) {
            successCount = s;
            failCount = f;
          },
        ),
        connectivity: mockConnectivity,
      );

      queue.enqueue(RequestOptions(path: '/a', method: 'POST'));
      queue.enqueue(RequestOptions(path: '/b', method: 'DELETE'));

      connectivityController.add([ConnectivityResult.wifi]);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(successCount, 0);
      expect(failCount, 2);

      queue.dispose();
    });

    test('clear empties the queue', () {
      final queue = OfflineRequestQueue(
        dio: dio,
        config: const OfflineQueueConfig(),
        connectivity: mockConnectivity,
      );

      queue.enqueue(RequestOptions(path: '/a', method: 'POST'));
      queue.clear();

      expect(queue.isEmpty, isTrue);
      queue.dispose();
    });

    test('forceReplay replays immediately', () async {
      int replayedCount = 0;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          replayedCount++;
          handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: 'ok'));
        },
      ));

      final queue = OfflineRequestQueue(
        dio: dio,
        config: const OfflineQueueConfig(),
        connectivity: mockConnectivity,
      );

      queue.enqueue(RequestOptions(path: '/a', method: 'PATCH'));
      await queue.forceReplay();

      expect(replayedCount, 1);
      expect(queue.isEmpty, isTrue);

      queue.dispose();
    });
  });
}
