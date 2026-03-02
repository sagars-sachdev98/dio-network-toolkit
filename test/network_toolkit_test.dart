import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the connectivity_plus platform channel
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return <String>['wifi'];
      }
      return null;
    },
  );

  late NetworkToolkit toolkit;

  /// Creates a toolkit with a mock adapter at the transport layer.
  NetworkToolkit createToolkit({
    required MockAdapter adapter,
    NetworkToolkitConfig? config,
  }) {
    final tk = NetworkToolkit(config ??
        NetworkToolkitConfig(
          baseUrl: 'https://api.test.com',
          enableLogging: false,
          retry: RetryConfig.none,
        ));
    tk.dio.httpClientAdapter = adapter;
    return tk;
  }

  tearDown(() {
    try {
      toolkit.dispose();
    } catch (_) {}
  });

  group('HTTP methods', () {
    test('GET returns Success with parsed data', () async {
      toolkit = createToolkit(
        adapter: MockAdapter.json(
            (_, __) => {'name': 'Alice', 'age': 30},
            statusCode: 200),
      );

      final result = await toolkit.get<Map<String, dynamic>>(
        '/user',
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, containsPair('name', 'Alice'));
      expect((result as Success).statusCode, 200);
    });

    test('POST sends data and returns Success', () async {
      RequestOptions? capturedOptions;
      toolkit = createToolkit(
        adapter: MockAdapter((options, _) {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'id': 1}),
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }),
      );

      final result = await toolkit.post<Map<String, dynamic>>(
        '/user',
        data: {'name': 'Bob'},
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(capturedOptions!.method, 'POST');
    });

    test('PUT returns Success', () async {
      RequestOptions? capturedOptions;
      toolkit = createToolkit(
        adapter: MockAdapter((options, _) {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'updated': true}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }),
      );

      final result = await toolkit.put<Map<String, dynamic>>(
        '/user/1',
        data: {'name': 'Updated'},
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(capturedOptions!.method, 'PUT');
    });

    test('PATCH returns Success', () async {
      RequestOptions? capturedOptions;
      toolkit = createToolkit(
        adapter: MockAdapter((options, _) {
          capturedOptions = options;
          return ResponseBody.fromString(
            jsonEncode({'patched': true}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }),
      );

      final result = await toolkit.patch<Map<String, dynamic>>(
        '/user/1',
        data: {'name': 'Patched'},
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(capturedOptions!.method, 'PATCH');
    });

    test('DELETE returns Success', () async {
      RequestOptions? capturedOptions;
      toolkit = createToolkit(
        adapter: MockAdapter((options, _) {
          capturedOptions = options;
          return ResponseBody.fromString('null', 204, headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
        }),
      );

      final result = await toolkit.delete<void>(
        '/user/1',
        fromJson: (_) {},
      );

      expect(result.isSuccess, isTrue);
      expect(capturedOptions!.method, 'DELETE');
    });
  });

  group('getList', () {
    test('parses list from root array', () async {
      toolkit = createToolkit(
        adapter: MockAdapter.json((_, __) => [
              {'id': 1},
              {'id': 2}
            ]),
      );

      final result = await toolkit.getList<Map<String, dynamic>>(
        '/items',
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.length, 2);
    });

    test('parses list from dataKey', () async {
      toolkit = createToolkit(
        adapter: MockAdapter.json((_, __) => {
              'items': [
                {'id': 1},
                {'id': 2}
              ]
            }),
      );

      final result = await toolkit.getList<Map<String, dynamic>>(
        '/items',
        dataKey: 'items',
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.length, 2);
    });

    test('returns Failure with FormatException when dataKey but not a Map',
        () async {
      toolkit = createToolkit(
        adapter: MockAdapter.json((_, __) => 'not a map'),
      );

      final result = await toolkit.getList<Map<String, dynamic>>(
        '/items',
        dataKey: 'items',
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isFailure, isTrue);
      expect((result as Failure).error.type, NetworkErrorType.parsing);
    });

    test('returns Failure with FormatException when data is not a List',
        () async {
      toolkit = createToolkit(
        adapter: MockAdapter.json((_, __) => 'not a list'),
      );

      final result = await toolkit.getList<Map<String, dynamic>>(
        '/items',
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isFailure, isTrue);
      expect((result as Failure).error.type, NetworkErrorType.parsing);
    });
  });

  group('Error handling', () {
    test('DioException becomes Failure with NetworkError', () async {
      toolkit = createToolkit(adapter: MockAdapter.error());

      final result = await toolkit.get<Map<String, dynamic>>(
        '/test',
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isFailure, isTrue);
      expect((result as Failure).error.type, NetworkErrorType.noConnection);
    });

    test('parsing error becomes Failure', () async {
      toolkit = createToolkit(
        adapter: MockAdapter.json((_, __) => 'not json'),
      );

      final result = await toolkit.get<Map<String, dynamic>>(
        '/test',
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(result.isFailure, isTrue);
      expect((result as Failure).error.type, NetworkErrorType.parsing);
    });

    test('onError callback is invoked', () async {
      NetworkError? capturedError;
      toolkit = createToolkit(
        config: NetworkToolkitConfig(
          baseUrl: 'https://api.test.com',
          enableLogging: false,
          retry: RetryConfig.none,
          onError: (e) => capturedError = e,
        ),
        adapter: MockAdapter.error(),
      );

      await toolkit.get<Map<String, dynamic>>(
        '/test',
        fromJson: (j) => j as Map<String, dynamic>,
      );

      expect(capturedError, isNotNull);
      expect(capturedError!.type, NetworkErrorType.noConnection);
    });
  });

  group('Options reuse safety', () {
    test('_opts does not mutate the original Options object', () async {
      toolkit = createToolkit(
        adapter: MockAdapter.json((_, __) => {'ok': true}),
      );

      final original = Options(headers: {'X-Custom': 'value'});

      await toolkit.get<Map<String, dynamic>>(
        '/test',
        fromJson: (j) => j as Map<String, dynamic>,
        options: original,
      );

      // The original Options should not have been mutated with isPublic
      expect(original.extra, isNull);
    });
  });

  group('raw()', () {
    test('returns Map<String, dynamic>', () async {
      toolkit = createToolkit(
        adapter: MockAdapter.json((_, __) => {'key': 'value'}),
      );

      final result = await toolkit.raw('GET', '/test');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, {'key': 'value'});
    });
  });

  group('NetworkToolkitFactory', () {
    test('creates and retrieves instances by name', () {
      final factory = NetworkToolkitFactory({
        'main': NetworkToolkitConfig(
            baseUrl: 'https://api.main.com', enableLogging: false),
        'auth': NetworkToolkitConfig(
            baseUrl: 'https://auth.main.com', enableLogging: false),
      });

      expect(factory['main'], isNotNull);
      expect(factory['auth'], isNotNull);
      expect(factory['unknown'], isNull);

      factory.dispose();
    });

    test('get() throws for unknown name', () {
      final factory = NetworkToolkitFactory({
        'main': NetworkToolkitConfig(
            baseUrl: 'https://api.main.com', enableLogging: false),
      });

      expect(factory.get('main'), isNotNull);
      expect(() => factory.get('unknown'), throwsA(isA<ArgumentError>()));

      factory.dispose();
    });
  });
}
