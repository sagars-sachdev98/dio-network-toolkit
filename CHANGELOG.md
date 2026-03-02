## 1.0.0

- Initial release
- Sealed `Result<T>` type with `Success` and `Failure`
- `NetworkToolkit` — unified API client with GET, POST, PUT, PATCH, DELETE, getList, raw
- `AuthInterceptor` — token injection + automatic 401 refresh with request queuing
- `RetryInterceptor` — exponential backoff + jitter, Retry-After support
- `ConnectivityInterceptor` — fail-fast offline detection
- `CacheInterceptor` — in-memory GET cache (networkFirst, cacheFirst, staleWhileRevalidate)
- `DedupInterceptor` — request deduplication for identical in-flight GETs
- `PrettyLogInterceptor` — structured debug-only logging
- `OfflineRequestQueue` — queue mutations when offline, auto-replay on reconnect
- `CancelTokenManager` — lifecycle-aware cancel token management
- `UploadManager` — single file, multi-file, and bytes upload with progress
- `NetworkToolkitFactory` — multi-base-URL support
- `ResultExtensions` — mapSuccess, flatMap, dataOr, onSuccess, onFailure
