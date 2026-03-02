import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../core/config.dart';

/// Queues mutation requests (POST/PUT/PATCH/DELETE) when offline.
/// Automatically replays them when connectivity is restored.
///
/// Use case: User places an order while in elevator (no signal).
/// The order request is queued and fires when they get signal back.
class OfflineRequestQueue {
  final Dio _dio;
  final OfflineQueueConfig _config;
  final Connectivity _connectivity;
  final _queue = <RequestOptions>[];
  StreamSubscription? _connectivitySub;
  bool _isReplaying = false;

  OfflineRequestQueue({
    required Dio dio,
    required OfflineQueueConfig config,
    Connectivity? connectivity,
  })  : _dio = dio,
        _config = config,
        _connectivity = connectivity ?? Connectivity() {
    _startListening();
  }

  int get queueLength => _queue.length;
  bool get isEmpty => _queue.isEmpty;

  /// Add a failed request to the queue for later replay.
  bool enqueue(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (!_config.queueableMethods.contains(method)) return false;
    if (_queue.length >= _config.maxQueueSize) return false;

    _queue.add(options);
    return true;
  }

  void _startListening() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none) && _queue.isNotEmpty) {
        _replay();
      }
    });
  }

  Future<void> _replay() async {
    if (_isReplaying || _queue.isEmpty) return;
    _isReplaying = true;

    final toReplay = List<RequestOptions>.from(_queue);
    _queue.clear();

    int success = 0;
    int fail = 0;

    for (final opts in toReplay) {
      try {
        await _dio.fetch(opts);
        success++;
      } catch (_) {
        fail++;
        // Don't re-queue failed replays to avoid infinite loops
      }
    }

    _config.onReplayComplete?.call(success, fail);
    _isReplaying = false;
  }

  /// Force replay (e.g., user taps "Retry All").
  Future<void> forceReplay() => _replay();

  /// Clear the queue.
  void clear() => _queue.clear();

  void dispose() {
    _connectivitySub?.cancel();
    _queue.clear();
  }
}
