# dio_network_toolkit

[![pub package](https://img.shields.io/pub/v/dio_network_toolkit.svg)](https://pub.dev/packages/dio_network_toolkit)
[![pub points](https://img.shields.io/pub/points/dio_network_toolkit)](https://pub.dev/packages/dio_network_toolkit/score)
[![popularity](https://img.shields.io/pub/popularity/dio_network_toolkit)](https://pub.dev/packages/dio_network_toolkit/score)
[![likes](https://img.shields.io/pub/likes/dio_network_toolkit)](https://pub.dev/packages/dio_network_toolkit/score)
[![CI](https://github.com/sagars-sachdev98/dio-network-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/sagars-sachdev98/dio-network-toolkit/actions/workflows/ci.yml)
[![License: BSD-3](https://img.shields.io/badge/license-BSD--3-blue.svg)](LICENSE)

Production-ready network layer for Flutter & Dart built on top of [Dio](https://pub.dev/packages/dio).

Auth refresh, smart retry, offline queue, response cache, request deduplication, cancel management, upload progress — all zero-boilerplate with sealed `Result` types.

## Why dio_network_toolkit?

| Concern | Raw Dio | dio_network_toolkit |
|---|---|---|
| Token refresh + request queuing | ~80 lines of interceptor code | `AuthConfig(tokenProvider: ..., refreshToken: ...)` |
| Retry with backoff & jitter | Write your own `Interceptor` | `RetryConfig(maxAttempts: 3)` |
| Offline detection + queue & replay | Manual connectivity checks everywhere | `OfflineQueueConfig(enabled: true)` |
| Response caching (3 strategies) | Not built-in | `CacheConfig(strategy: CacheStrategy.networkFirst)` |
| Request deduplication | Not built-in | Automatic for identical in-flight GETs |
| Error handling | `try/catch` DioException everywhere | Sealed `Result<T>` with pattern matching |
| Upload with progress | ~20 lines per upload | `api.upload.file(...)` one-liner |

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
  dio_network_toolkit: ^1.0.3
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
