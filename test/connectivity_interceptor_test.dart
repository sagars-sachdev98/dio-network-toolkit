import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'test_helpers.dart';

@GenerateMocks([Connectivity])
import 'connectivity_interceptor_test.mocks.dart';

void main() {
  late MockConnectivity mockConnectivity;
  late Dio dio;

  setUp(() {
    mockConnectivity = MockConnectivity();
    dio = Dio(BaseOptions(baseUrl: 'https://api.test.com'));
    // Use mock adapter to prevent real network calls
    dio.httpClientAdapter =
        MockAdapter.json((_, __) => {'ok': true}, statusCode: 200);
  });

  tearDown(() {
    dio.close();
  });

  group('ConnectivityInterceptor', () {
    test('passes through when online', () async {
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      dio.interceptors
          .add(ConnectivityInterceptor(connectivity: mockConnectivity));

      final response = await dio.get('/test');
      expect(response.statusCode, 200);
    });

    test('rejects when offline', () async {
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      dio.interceptors
          .add(ConnectivityInterceptor(connectivity: mockConnectivity));

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.type, DioExceptionType.connectionError);
        expect(e.message, contains('No internet'));
      }
    });

    test('passes through for mobile connection', () async {
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.mobile]);

      dio.interceptors
          .add(ConnectivityInterceptor(connectivity: mockConnectivity));
  
      final response = await dio.get('/test');
      expect(response.statusCode, 200);
    });
  });
}
