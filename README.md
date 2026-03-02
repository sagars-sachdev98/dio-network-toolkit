# dio_network_toolkit

Production-ready network layer for Flutter & Dart built on top of [Dio](https://pub.dev/packages/dio).

Auth refresh, smart retry, offline queue, response cache, request deduplication, cancel management, upload progress — all zero-boilerplate with sealed `Result` types.

## Features

- **Sealed Result types** — `Success<T>` / `Failure` with pattern matching, no exceptions to catch
- **Auth interceptor** — automatic token injection, 401 refresh with request queuing
- **Smart retry** — exponential backoff + jitter, Retry-After header support, idempotency-aware
- **Connectivity check** — fail-fast when offline
- **Response cache** — in-memory GET cache with networkFirst / cacheFirst / staleWhileRevalidate strategies
- **Request deduplication** — identical in-flight GETs share a single network call
- **Offline queue** — auto-queue mutations (POST/PUT/PATCH/DELETE) and replay when back online
- **Cancel token manager** — lifecycle-aware request cancellation
- **Upload manager** — single file, multi-file, and bytes upload with progress tracking
- **Multi-base-URL** — `NetworkToolkitFactory` for apps with multiple API hosts
- **Functional extensions** — `mapSuccess`, `flatMap`, `dataOr`, `onSuccess`, `onFailure`

## Installation

```yaml
dependencies:
  dio_network_toolkit: ^1.0.0
```

## Quick Start

```dart
import 'package:dio_network_toolkit/dio_network_toolkit.dart';

// 1. Create the toolkit
final api = NetworkToolkit(NetworkToolkitConfig(
  baseUrl: 'https://api.example.com/v1',
  auth: AuthConfig(
    tokenProvider: () => storage.read('access_token'),
    refreshToken: (dio) async {
      final res = await dio.post('/auth/refresh');
      return res.data['accessToken'];
    },
    onTokenExpired: () => navigateToLogin(),
  ),
  retry: const RetryConfig(maxAttempts: 3),
  cache: const CacheConfig(strategy: CacheStrategy.networkFirst),
  offlineQueue: const OfflineQueueConfig(enabled: true),
  onError: (e) => showToast(e.userMessage ?? 'Error'),
));

// 2. Make requests
final result = await api.get<User>('/me', fromJson: User.fromJson);

// 3. Handle result with pattern matching
switch (result) {
  case Success(:final data): print(data.name);
  case Failure(:final error): print(error.userMessage);
}
```

## Usage

### Repository pattern

```dart
class UserRepository {
  final NetworkToolkit _api;
  UserRepository(this._api);

  Future<Result<User>> getProfile() =>
      _api.get('/me', fromJson: User.fromJson);

  Future<Result<List<Post>>> getPosts({int page = 1}) =>
      _api.getList('/posts',
          fromJson: Post.fromJson,
          dataKey: 'data',
          queryParameters: {'page': page});
}
```

### Upload with progress

```dart
final result = await api.upload.file<UploadResponse>(
  '/documents/upload',
  filePath: '/path/to/file.pdf',
  fromJson: UploadResponse.fromJson,
  onProgress: (sent, total, percent) {
    emit(UploadProgress(percent));
  },
);
```

### Cache control

```dart
// Skip cache for a single request
await api.get<User>('/me', fromJson: User.fromJson, noCache: true);

// Invalidate after mutation
await api.post('/me', data: updates, fromJson: User.fromJson);
api.invalidateCache('/me');
```

See the [example](example/) for a complete working app.

## License

BSD-3-Clause. See [LICENSE](LICENSE).
# dio-network-toolkit
# dio-network-toolkit
