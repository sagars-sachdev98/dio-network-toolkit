import 'package:dio/dio.dart';

/// Manages CancelTokens tied to a lifecycle (page, BLoC, etc.).
///
/// ```dart
/// class OrderBloc extends Bloc<OrderEvent, OrderState> {
///   final _cancelManager = CancelTokenManager();
///
///   Future<void> _loadOrders(...) async {
///     final result = await toolkit.get('/orders',
///       cancelToken: _cancelManager.token('loadOrders'),
///       fromJson: ...
///     );
///   }
///
///   @override
///   Future<void> close() {
///     _cancelManager.cancelAll(); // cancel all in-flight on dispose
///     return super.close();
///   }
/// }
/// ```
class CancelTokenManager {
  final _tokens = <String, CancelToken>{};

  /// Get or create a CancelToken for the given tag.
  /// If a previous token for this tag exists and is cancelled, creates a new one.
  CancelToken token(String tag) {
    final existing = _tokens[tag];
    if (existing != null && !existing.isCancelled) return existing;
    final newToken = CancelToken();
    _tokens[tag] = newToken;
    return newToken;
  }

  /// Cancel a specific tagged request.
  void cancel(String tag, [String? reason]) {
    _tokens[tag]?.cancel(reason ?? 'Cancelled: $tag');
    _tokens.remove(tag);
  }

  /// Cancel all in-flight requests. Call in dispose/close.
  void cancelAll([String? reason]) {
    for (final entry in _tokens.entries) {
      if (!entry.value.isCancelled) {
        entry.value.cancel(reason ?? 'CancelTokenManager: cancelAll');
      }
    }
    _tokens.clear();
  }

  /// Check if a tag has an active (non-cancelled) token.
  bool isActive(String tag) {
    final t = _tokens[tag];
    return t != null && !t.isCancelled;
  }
}
