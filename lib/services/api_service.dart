import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../utils/constants.dart';

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
  ApiService({String? baseUrl, String? authToken})
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
    _dio.interceptors.add(_authInterceptor());
    if (AppConstants.debugMode) {
      _dio.interceptors.add(_debugInterceptor());
    }
  }

  final Dio _dio;
  String? _authToken;

  /// Updates the auth token used in subsequent requests.
  void setAuthToken(String? token) {
    _authToken = token;
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

  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _authToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    );
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
    final debug = AppConstants.debugMode;
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
