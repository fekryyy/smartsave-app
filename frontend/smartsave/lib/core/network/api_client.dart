import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../errors/failures.dart';
import 'result.dart';

/// Singleton HTTP client with:
/// - JWT token injection & silent refresh
/// - Retry with exponential backoff
/// - Request cancellation via CancelToken management
/// - Structured [Result] return types
class ApiClient {
  // ── Singleton ──
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Active cancel tokens per path — for cancelling in-flight requests
  final Map<String, CancelToken> _cancelTokens = {};

  // Refresh lock
  bool _isRefreshing = false;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_dio, _storage, this),
      _RetryInterceptor(),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => log('[API] $obj'),
      ),
    ]);
  }

  /// Raw Dio instance for advanced use cases.
  Dio get dio => _dio;

  // ── Token management ──

  Future<String?> getToken() => _storage.read(key: 'auth_token');
  Future<void> setToken(String token) => _storage.write(key: 'auth_token', value: token);
  Future<void> removeToken() => _storage.delete(key: 'auth_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');
  Future<void> setRefreshToken(String token) => _storage.write(key: 'refresh_token', value: token);
  Future<void> removeRefreshToken() => _storage.delete(key: 'refresh_token');
  Future<void> clearAllTokens() => _storage.deleteAll();

  /// Marks the session as rejected (tokens invalid).
  Future<void> rejectSession() async {
    await clearAllTokens();
    _isRefreshing = false;
  }

  /// Whether a token refresh is in progress.
  bool get isRefreshing => _isRefreshing;

  // ── Cancel-token management ──

  /// Cancel any in-flight request for a given path prefix.
  /// E.g., cancelRequests('transactions') cancels all transactions API calls.
  void cancelRequests(String pathPrefix) {
    final matching = _cancelTokens.keys.where((k) => k.startsWith(pathPrefix));
    for (final key in matching) {
      _cancelTokens[key]?.cancel('Request cancelled: new request in flight');
      _cancelTokens.remove(key);
    }
  }

  /// Cancel ALL in-flight requests.
  void cancelAll() {
    for (final token in _cancelTokens.values) {
      token.cancel('All requests cancelled');
    }
    _cancelTokens.clear();
  }

  /// Internal: track a cancel token for a path.
  void _trackCancel(String path, CancelToken token) {
    _cancelTokens[path] = token;
  }

  /// Internal: remove a cancel token after completion.
  void _untrackCancel(String path) {
    _cancelTokens.remove(path);
  }

  // ── HTTP methods returning Result ──

  /// GET request.
  Future<Result<Map<String, dynamic>>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool cancelPrevious = false,
  }) async {
    if (cancelPrevious) cancelRequests(path);
    final cancelToken = CancelToken();
    _trackCancel(path, cancelToken);

    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return Success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return FailureResult(_mapDioError(e));
    } finally {
      _untrackCancel(path);
    }
  }

  /// POST request.
  Future<Result<Map<String, dynamic>>> post(
    String path, {
    dynamic data,
    bool cancelPrevious = false,
  }) async {
    if (cancelPrevious) cancelRequests(path);
    final cancelToken = CancelToken();
    _trackCancel(path, cancelToken);

    try {
      final response = await _dio.post(path, data: data, cancelToken: cancelToken);
      return Success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return FailureResult(_mapDioError(e));
    } finally {
      _untrackCancel(path);
    }
  }

  /// PUT request.
  Future<Result<Map<String, dynamic>>> put(
    String path, {
    dynamic data,
    bool cancelPrevious = false,
  }) async {
    if (cancelPrevious) cancelRequests(path);
    final cancelToken = CancelToken();
    _trackCancel(path, cancelToken);

    try {
      final response = await _dio.put(path, data: data, cancelToken: cancelToken);
      return Success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return FailureResult(_mapDioError(e));
    } finally {
      _untrackCancel(path);
    }
  }

  /// DELETE request.
  Future<Result<Map<String, dynamic>>> delete(
    String path, {
    bool cancelPrevious = false,
  }) async {
    if (cancelPrevious) cancelRequests(path);
    final cancelToken = CancelToken();
    _trackCancel(path, cancelToken);

    try {
      final response = await _dio.delete(path, cancelToken: cancelToken);
      return Success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return FailureResult(_mapDioError(e));
    } finally {
      _untrackCancel(path);
    }
  }

  /// GET raw bytes (for file downloads).
  Future<Result<Uint8List>> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
      );
      return Success(response.data as Uint8List);
    } on DioException catch (e) {
      return FailureResult(_mapDioError(e));
    }
  }

  /// Upload a file via multipart form.
  Future<Result<Map<String, dynamic>>> uploadFile(
    String path,
    String filePath,
    String fieldName,
  ) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(path, data: formData);
      return Success(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return FailureResult(_mapDioError(e));
    }
  }

  // ── Error mapping ──

  /// Maps a [DioException] to an appropriate [Failure] subclass.
  Failure _mapDioError(DioException e) {
    // Cancellation is not an error
    if (e.type == DioExceptionType.cancel) {
      return const Failure(message: 'Request cancelled');
    }

    // Network errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const ConnectionFailure();
    }

    // No internet
    if (e.type == DioExceptionType.connectionError) {
      return const ConnectionFailure();
    }

    // Response errors
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    final message = body is Map ? (body['message'] as String? ?? e.message) : e.message;

    if (statusCode == 401) {
      return AuthFailure(message: message ?? 'Unauthorized', statusCode: statusCode);
    }
    if (statusCode == 403) {
      return AuthFailure(message: message ?? 'Access denied', statusCode: statusCode);
    }
    if (statusCode == 404) {
      return ServerFailure(message: message ?? 'Not found', statusCode: statusCode);
    }
    if (statusCode == 422 || statusCode == 400) {
      final errors = body is Map ? body['errors'] : null;
      return ValidationFailure(
        message: message ?? 'Validation error',
        statusCode: statusCode,
        errors: errors,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return ServerFailure(
        message: message ?? 'Server error',
        statusCode: statusCode,
      );
    }

    return ServerFailure(message: message ?? 'Unexpected error', statusCode: statusCode);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Interceptors
// ─────────────────────────────────────────────────────────────────────

/// Injects the JWT Bearer token on every request and handles 401
/// by attempting a silent token refresh.
class _AuthInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage storage;
  final ApiClient client;

  _AuthInterceptor(this.dio, this.storage, this.client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip auth header for auth endpoints (they handle their own auth)
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/register') ||
        options.path.contains('/auth/google') ||
        options.path.contains('/auth/forgot-password') ||
        options.path.contains('/auth/reset-password') ||
        options.path.contains('/auth/refresh-token')) {
      handler.next(options);
      return;
    }

    // Skip if this is a retry (already has refreshed token)
    if (options.headers['X-Retry'] == 'true') {
      handler.next(options);
      return;
    }

    final token = await storage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Never retry auth endpoints
    final path = err.requestOptions.path;
    if (path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/google') ||
        path.contains('/auth/refresh-token') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password') ||
        err.requestOptions.headers['X-Retry'] == 'true') {
      handler.next(err);
      return;
    }

    // Prevent concurrent refresh loops
    if (client._isRefreshing) {
      handler.next(err);
      return;
    }

    try {
      client._isRefreshing = true;
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        await client.rejectSession();
        handler.next(err);
        return;
      }

      final response = await dio.post('/auth/refresh-token', data: {
        'refreshToken': refreshToken,
      });

      final data = response.data;
      final newToken = data['data']['token'] as String?;
      final newRefreshToken = data['data']['refreshToken'] as String?;

      if (newToken == null) {
        await client.rejectSession();
        handler.next(err);
        return;
      }

      await storage.write(key: 'auth_token', value: newToken);
      if (newRefreshToken != null) {
        await storage.write(key: 'refresh_token', value: newRefreshToken);
      }

      // Retry the failed request with the new token
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';
      retryOptions.headers['X-Retry'] = 'true';
      client._isRefreshing = false;
      final retryResponse = await dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      client._isRefreshing = false;
      await client.rejectSession();
      handler.next(err);
    }
  }
}

/// Retries failed requests with exponential backoff.
/// Skips retries for 4xx client errors (except 429 rate-limit).
class _RetryInterceptor extends Interceptor {
  final int maxRetries = 2;
  final Duration baseDelay = const Duration(milliseconds: 500);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only retry on server errors (5xx) or network errors, or 429 rate-limit
    final statusCode = err.response?.statusCode ?? 0;
    final isRetryable = statusCode >= 500 ||
        statusCode == 429 ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;

    if (!isRetryable) {
      handler.next(err);
      return;
    }

    // Get retry count from request options or default to 0
    final retryCount = (err.requestOptions.extra['retryCount'] as int?) ?? 0;
    if (retryCount >= maxRetries) {
      handler.next(err);
      return;
    }

    // Wait with exponential backoff
    final delay = baseDelay * (1 << retryCount); // 500ms, 1s, 2s
    await Future.delayed(delay);

    // Update retry count
    err.requestOptions.extra['retryCount'] = retryCount + 1;

    try {
      final response = await Dio().fetch(err.requestOptions);
      handler.resolve(response);
    } catch (e) {
      handler.next(err);
    }
  }
}

/// Extension on Future<Result<T>> to directly unwrap the Result.
/// Allows: `await apiClient.get(path).dataOrThrow` as a replacement for the old
/// synchronous return pattern where API calls threw on error.
extension FutureResultUnwrap<T> on Future<Result<T>> {
  /// Returns the data if the result is a Success, or throws the Failure.
  Future<T> get dataOrThrow async => (await this).dataOrThrow;
}
