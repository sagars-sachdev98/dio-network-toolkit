import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';

void main() {
  group('RetryConfig.delayForAttempt', () {
    test('first attempt returns base delay (no jitter)', () {
      const config = RetryConfig(baseDelay: Duration(seconds: 1), useJitter: false);
      expect(config.delayForAttempt(0), const Duration(seconds: 1));
    });

    test('exponential growth', () {
      const config = RetryConfig(baseDelay: Duration(seconds: 1), useJitter: false);
      expect(config.delayForAttempt(1), const Duration(seconds: 2));
      expect(config.delayForAttempt(2), const Duration(seconds: 4));
      expect(config.delayForAttempt(3), const Duration(seconds: 8));
    });

    test('capped at maxDelay', () {
      const config = RetryConfig(
        baseDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 10),
        useJitter: false,
      );
      expect(config.delayForAttempt(5), const Duration(seconds: 10));
    });

    test('clamped for very large attempt (overflow protection)', () {
      const config = RetryConfig(
        baseDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 30),
        useJitter: false,
      );
      // attempt=100 should not overflow — clamped to 2^10=1024, then capped at maxDelay
      final delay = config.delayForAttempt(100);
      expect(delay, const Duration(seconds: 30));
    });

    test('jitter produces delay within range', () {
      const config = RetryConfig(
        baseDelay: Duration(seconds: 1),
        useJitter: true,
      );
      // Run many times to probabilistically test
      for (int i = 0; i < 50; i++) {
        final delay = config.delayForAttempt(0);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
        expect(delay.inMilliseconds, lessThanOrEqualTo(1000));
      }
    });
  });

  group('RetryConfig presets', () {
    test('none has 0 maxAttempts', () {
      expect(RetryConfig.none.maxAttempts, 0);
    });

    test('aggressive has 5 maxAttempts and null retryableMethods', () {
      expect(RetryConfig.aggressive.maxAttempts, 5);
      expect(RetryConfig.aggressive.retryableMethods, isNull);
    });
  });

  group('NetworkToolkitConfig baseUrl validation', () {
    test('rejects empty baseUrl', () {
      expect(
        () => NetworkToolkitConfig(baseUrl: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects URL without scheme', () {
      expect(
        () => NetworkToolkitConfig(baseUrl: 'example.com'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects URL without host', () {
      expect(
        () => NetworkToolkitConfig(baseUrl: 'https://'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts valid URL', () {
      expect(
        () => NetworkToolkitConfig(baseUrl: 'https://api.example.com'),
        returnsNormally,
      );
    });

    test('accepts URL with path', () {
      expect(
        () => NetworkToolkitConfig(baseUrl: 'https://api.example.com/v1'),
        returnsNormally,
      );
    });
  });
}
