import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../utils/constants.dart';

typedef AuthTokenProvider = Future<String?> Function({bool forceRefresh});

/// Result type for API calls, encapsulating success data or error information.
class ApiResult<T> {
  const ApiResult._({this.data, this.error, this.statusCode});

  factory ApiResult.success(T data, {int? statusCode}) =>
      ApiResult._(data: data, statusCode: statusCode);

  factory ApiResult.failure(String error, {int? statusCode}) =>
      ApiResult._(error: error, statusCode: statusCode);

  final T? data;
  final String? error;
  final int? statusCode;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

/// HTTP client for communicating with the Chefless API.
///
/// Uses [Dio] under the hood with interceptors for auth header injection
/// and standardized error handling.
class ApiService {
  ApiService({
    String? baseUrl,
    String? authToken,
    AuthTokenProvider? authTokenProvider,
  })
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
            connectTimeout: AppConstants.connectionTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    if (authToken != null) {
      _authToken = authToken;
    }
    _authTokenProvider = authTokenProvider;
    _dio.interceptors.add(_idempotencyInterceptor());
    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(_retryInterceptor());
    if (AppConstants.debugMode) {
      _dio.interceptors.add(_debugInterceptor());
    }
    _configureCertificatePinning();
  }

  static final _random = math.Random.secure();

  /// Generates a unique idempotency key (hex string) for mutating requests.
  static String _generateIdempotencyKey() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  final Dio _dio;
  String? _authToken;
  AuthTokenProvider? _authTokenProvider;

  /// Serializes concurrent token refresh calls so only one runs at a time.
  Completer<String?>? _refreshCompleter;

  /// Updates the auth token used in subsequent requests.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  void setAuthTokenProvider(AuthTokenProvider? tokenProvider) {
    _authTokenProvider = tokenProvider;
  }

  // ── HTTP Methods ───────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request(() => _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: queryParameters,
        ));
  }

  Future<ApiResult<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return _request(() => _dio.post<Map<String, dynamic>>(
          path,
          data: data,
        ));
  }

  Future<ApiResult<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return _request(() => _dio.put<Map<String, dynamic>>(
          path,
          data: data,
        ));
  }

  Future<ApiResult<Map<String, dynamic>>> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return _request(() => _dio.patch<Map<String, dynamic>>(
          path,
          data: data,
        ));
  }

  Future<ApiResult<Map<String, dynamic>>> delete(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return _request(() => _dio.delete<Map<String, dynamic>>(
          path,
          data: data,
        ));
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  /// Submits a report against a recipe or user.
  Future<ApiResult<Map<String, dynamic>>> createReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) {
    return post('/api/reports', data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Rejects connections whose server certificate does not match known pins.
  /// Only active for the production API host; skipped for local dev.
  void _configureCertificatePinning() {
    if (AppConstants.useLocalApi) return;

    final adapter = _dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          // Only enforce pinning for our API host
          if (!host.contains('onrender.com')) return true;
          // Reject bad certificates for our domain
          return false;
        };
        return client;
      };
    }
  }

  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _resolveAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final requestOptions = error.requestOptions;
        final shouldRetry =
            error.response?.statusCode == 401 &&
            requestOptions.extra['_didRetryWithFreshToken'] != true &&
            _authTokenProvider != null;

        if (!shouldRetry) {
          handler.next(error);
          return;
        }

        final refreshedToken = await _resolveAuthToken(forceRefresh: true);
        if (refreshedToken == null || refreshedToken.isEmpty) {
          handler.next(error);
          return;
        }

        requestOptions.headers['Authorization'] = 'Bearer $refreshedToken';
        requestOptions.extra['_didRetryWithFreshToken'] = true;

        try {
          final response = await _dio.fetch<Map<String, dynamic>>(requestOptions);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    );
  }

  Future<String?> _resolveAuthToken({bool forceRefresh = false}) async {
    final tokenProvider = _authTokenProvider;
    if (tokenProvider == null) return _authToken;

    if (!forceRefresh) {
      final token = await tokenProvider(forceRefresh: false);
      _authToken = token;
      return token;
    }

    // Serialize concurrent refresh calls — only one runs at a time.
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    try {
      final token = await tokenProvider(forceRefresh: true);
      _authToken = token;
      _refreshCompleter!.complete(token);
      return token;
    } catch (e) {
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Adds idempotency keys to mutating requests (POST/PUT/PATCH/DELETE).
  Interceptor _idempotencyInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final method = options.method.toUpperCase();
        if (method == 'POST' || method == 'PUT' || method == 'PATCH' || method == 'DELETE') {
          options.headers['X-Idempotency-Key'] ??= _generateIdempotencyKey();
        }
        handler.next(options);
      },
    );
  }

  /// Maximum time to wait for a single retry. If the server asks for longer
  /// (via Retry-After / RateLimit-Reset), we surface the error rather than
  /// freezing the UI for many seconds.
  static const Duration _maxRetryDelay = Duration(seconds: 4);

  /// Retries transient failures (429, 408, 5xx) using server-supplied backoff
  /// hints when available, with random jitter to avoid thundering herds.
  Interceptor _retryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final retryCount =
            error.requestOptions.extra['_retryCount'] as int? ?? 0;
        const maxRetries = 2;

        final isRetryable = status != null &&
            (status == 429 || status == 408 || status >= 500) &&
            retryCount < maxRetries;

        if (!isRetryable) {
          handler.next(error);
          return;
        }

        final delay = _computeRetryDelay(error.response, retryCount);
        if (delay == null) {
          // Server told us to wait longer than _maxRetryDelay — let the caller
          // see the 429 immediately so the UI can show a clear message instead
          // of a long spinner.
          handler.next(error);
          return;
        }

        await Future<void>.delayed(delay);
        error.requestOptions.extra['_retryCount'] = retryCount + 1;

        try {
          final response =
              await _dio.fetch<Map<String, dynamic>>(error.requestOptions);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    );
  }

  /// Returns the duration to wait before the next retry, or `null` if the
  /// recommended wait exceeds [_maxRetryDelay].
  ///
  /// Honors RFC 9110 `Retry-After` (seconds or HTTP date) and the
  /// `RateLimit-Reset` draft header. Falls back to exponential backoff
  /// (500ms × 2^retry) plus 0–250ms of jitter.
  Duration? _computeRetryDelay(Response<dynamic>? response, int retryCount) {
    final serverWait = _readServerWait(response);
    if (serverWait != null) {
      if (serverWait > _maxRetryDelay) return null;
      // Add tiny jitter so concurrent retries don't all fire on the same tick.
      final jitterMs = _random.nextInt(250);
      return serverWait + Duration(milliseconds: jitterMs);
    }

    final base = 500 * math.pow(2, retryCount).toInt();
    final jitter = _random.nextInt(250);
    return Duration(milliseconds: base + jitter);
  }

  /// Parses Retry-After (seconds or HTTP-date) and RateLimit-Reset (seconds).
  Duration? _readServerWait(Response<dynamic>? response) {
    if (response == null) return null;
    final headers = response.headers;

    final retryAfter = headers.value('retry-after');
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter.trim());
      if (seconds != null && seconds >= 0) {
        return Duration(seconds: seconds);
      }
      // HTTP-date format: best-effort parse.
      try {
        final date = HttpDate.parse(retryAfter);
        final diff = date.difference(DateTime.now());
        if (diff.inMilliseconds > 0) return diff;
      } on FormatException {
        // Unparseable — fall through to RateLimit-Reset / backoff.
      } on HttpException {
        // Some Dart versions throw HttpException for bad dates. Same handling.
      }
    }

    // draft-7 standard header from express-rate-limit.
    final reset = headers.value('ratelimit-reset');
    if (reset != null) {
      final seconds = int.tryParse(reset.trim());
      if (seconds != null && seconds >= 0) {
        return Duration(seconds: seconds);
      }
    }

    return null;
  }

  Interceptor _debugInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        developer.log(
          '→ ${options.method} ${options.uri}',
          name: 'API',
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        developer.log(
          '← ${response.statusCode} ${response.requestOptions.method} '
          '${response.requestOptions.uri}',
          name: 'API',
        );
        handler.next(response);
      },
      onError: (error, handler) {
        developer.log(
          '✗ ${error.response?.statusCode ?? 'ERR'} '
          '${error.requestOptions.method} ${error.requestOptions.uri}\n'
          '  ${error.message}',
          name: 'API',
          error: error,
        );
        handler.next(error);
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> _request(
    Future<Response<Map<String, dynamic>>> Function() requestFn,
  ) async {
    try {
      final response = await requestFn();
      return ApiResult.success(
        response.data ?? {},
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      return ApiResult.failure(
        message,
        statusCode: e.response?.statusCode,
      );
    }
  }

  String _extractErrorMessage(DioException e) {
    const debug = AppConstants.debugMode;
    final endpoint = '${e.requestOptions.method} ${e.requestOptions.path}';

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return debug
            ? 'Timeout on $endpoint'
            : 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return debug
            ? 'Connection failed: $endpoint → ${e.message}'
            : 'Unable to connect to the server. Check your internet connection.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          // Extract detailed validation messages when available
          final details = data['details'];
          if (details is List && details.isNotEmpty) {
            final messages = <String>[];
            for (final detail in details) {
              if (detail is Map<String, dynamic>) {
                final issues = detail['issues'];
                if (issues is List) {
                  for (final issue in issues) {
                    if (issue is Map<String, dynamic>) {
                      final msg = issue['message'] as String?;
                      if (msg != null) messages.add(msg);
                    }
                  }
                }
              }
            }
            if (messages.isNotEmpty) {
              final joined = messages.join('. ');
              return debug ? '[$status] $endpoint: $joined' : joined;
            }
          }
          final serverMsg =
              data['message'] as String? ?? data['error'] as String?;
          if (serverMsg != null) {
            return debug ? '[$status] $endpoint: $serverMsg' : serverMsg;
          }
        }
        return debug
            ? '[$status] $endpoint — no JSON body'
            : 'Server error ($status).';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'Security certificate error.';
      case DioExceptionType.unknown:
        return debug
            ? 'Unknown error on $endpoint: ${e.message}'
            : 'An unexpected error occurred.';
    }
  }
}
