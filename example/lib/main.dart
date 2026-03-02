import 'package:dio_network_toolkit/dio_network_toolkit.dart';
import 'package:flutter/foundation.dart';

// ── 1. Define your models ─────────────────────────────────────────────

class User {
  final String id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(dynamic json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
      );
}

class Post {
  final String id;
  final String title;

  Post({required this.id, required this.title});

  factory Post.fromJson(dynamic json) => Post(
        id: json['id'],
        title: json['title'],
      );
}

// ── 2. Create the toolkit (once, in your DI container) ────────────────

final api = NetworkToolkit(
  NetworkToolkitConfig(
    baseUrl: 'https://api.example.com/v1',

    // Auth: works with ANY storage (SharedPrefs, SecureStorage, Hive, etc.)
    auth: AuthConfig(
      tokenProvider: () async {
        // return await YourStorage.read('access_token');
        return 'your-access-token';
      },
      refreshToken: (dio) async {
        // final res = await dio.post('/auth/refresh', data: {...});
        // return res.data['accessToken'];
        return 'new-token';
      },
      onTokenExpired: () {
        // Navigate to login screen
        debugPrint('Token expired — redirect to login');
      },
    ),

    // Retry: 3 attempts with exponential backoff
    retry: const RetryConfig(
      maxAttempts: 3,
      retryableStatusCodes: {500, 502, 503, 504, 429},
    ),

    // Cache: network-first for GET requests
    cache: const CacheConfig(
      strategy: CacheStrategy.networkFirst,
      maxAge: Duration(minutes: 5),
    ),

    // Offline queue: auto-replay mutations when back online
    offlineQueue: OfflineQueueConfig(
      enabled: true,
      onReplayComplete: (success, fail) {
        debugPrint('Replayed: $success ok, $fail failed');
      },
    ),

    enableLogging: kDebugMode,

    // Global error handler — show toast, log to analytics, etc.
    onError: (error) {
      debugPrint('Error ${error.type}: ${error.userMessage}');
    },
  ),
);

// ── 3. Repository layer (Clean Architecture) ──────────────────────────

class UserRepository {
  final NetworkToolkit _api;
  UserRepository(this._api);

  Future<Result<User>> getProfile() =>
      _api.get('/me', fromJson: User.fromJson);

  Future<Result<User>> updateProfile(Map<String, dynamic> data) =>
      _api.put('/me', data: data, fromJson: User.fromJson);
}

class PostRepository {
  final NetworkToolkit _api;
  PostRepository(this._api);

  Future<Result<List<Post>>> getPosts({int page = 1}) =>
      _api.getList('/posts',
          fromJson: Post.fromJson,
          dataKey: 'data',
          queryParameters: {'page': page});

  // Public endpoint (no auth header)
  Future<Result<List<Post>>> getFeatured() =>
      _api.getList('/posts/featured',
          fromJson: Post.fromJson, dataKey: 'data', isPublic: true);
}

// ── 4. Main ───────────────────────────────────────────────────────────

void main() async {
  // Simple usage
  final result = await api.get<User>('/me', fromJson: User.fromJson);

  result.when(
    success: (user, statusCode, raw) {
      debugPrint('Hello, ${user.name}!');
    },
    failure: (error) {
      debugPrint('Error: ${error.userMessage}');
      if (error.isRetryable) debugPrint('Show retry button');
    },
  );

  // List with pagination
  final posts = await api.getList<Post>(
    '/posts',
    fromJson: Post.fromJson,
    dataKey: 'data',
    queryParameters: {'page': 1, 'limit': 20},
  );

  posts.when(
    success: (data, _, __) => debugPrint('Got ${data.length} posts'),
    failure: (error) => debugPrint('Failed: ${error.userMessage}'),
  );

  // Functional chaining
  final userName = (await api.get<User>('/me', fromJson: User.fromJson))
      .mapSuccess((user) => user.name)
      .dataOr('Anonymous');

  debugPrint('User: $userName');
}
