import 'package:flutter_test/flutter_test.dart';
import 'package:dio_network_toolkit/dio_network_toolkit.dart';

void main() {
  late CancelTokenManager manager;

  setUp(() {
    manager = CancelTokenManager();
  });

  group('token()', () {
    test('creates a new token for a tag', () {
      final t = manager.token('load');
      expect(t, isA<CancelToken>());
      expect(t.isCancelled, isFalse);
    });

    test('returns the same token for the same tag', () {
      final t1 = manager.token('load');
      final t2 = manager.token('load');
      expect(identical(t1, t2), isTrue);
    });

    test('creates a new token after the previous was cancelled', () {
      final t1 = manager.token('load');
      manager.cancel('load');
      final t2 = manager.token('load');
      expect(identical(t1, t2), isFalse);
      expect(t2.isCancelled, isFalse);
    });
  });

  group('cancel()', () {
    test('cancels a specific token', () {
      final t = manager.token('load');
      manager.cancel('load');
      expect(t.isCancelled, isTrue);
    });

    test('cancel non-existent tag does not throw', () {
      expect(() => manager.cancel('nonexistent'), returnsNormally);
    });

    test('passes reason to token', () {
      final t = manager.token('load');
      manager.cancel('load', 'user tapped back');
      expect(t.isCancelled, isTrue);
    });
  });

  group('cancelAll()', () {
    test('cancels all active tokens', () {
      final t1 = manager.token('a');
      final t2 = manager.token('b');
      final t3 = manager.token('c');
      manager.cancelAll();
      expect(t1.isCancelled, isTrue);
      expect(t2.isCancelled, isTrue);
      expect(t3.isCancelled, isTrue);
    });

    test('after cancelAll, isActive returns false', () {
      manager.token('a');
      manager.cancelAll();
      expect(manager.isActive('a'), isFalse);
    });
  });

  group('isActive()', () {
    test('returns true for active token', () {
      manager.token('load');
      expect(manager.isActive('load'), isTrue);
    });

    test('returns false for cancelled token', () {
      manager.token('load');
      manager.cancel('load');
      expect(manager.isActive('load'), isFalse);
    });

    test('returns false for unknown tag', () {
      expect(manager.isActive('unknown'), isFalse);
    });
  });
}
