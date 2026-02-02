import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../storage/secure_storage.dart';
import 'api_response.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  Function? onUnauthorized;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await SecureStorage.clearAll();
            onUnauthorized?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  void setUnauthorizedCallback(Function callback) {
    onUnauthorized = callback;
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(path, data: data);
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(path);
      return _handleResponse(response, fromJson);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  ApiResponse<T> _handleResponse<T>(Response response, T Function(dynamic)? fromJson) {
    final data = response.data;
    if (fromJson != null) {
      return ApiResponse.success(fromJson(data), statusCode: response.statusCode);
    }
    return ApiResponse.success(data as T, statusCode: response.statusCode);
  }

  ApiResponse<T> _handleError<T>(DioException e) {
    final response = e.response;
    String message = 'An error occurred';
    Map<String, List<String>>? errors;

    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        message = data['message'] ?? message;
        if (data['errors'] != null) {
          errors = (data['errors'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          );
        }
      }
    } else {
      message = e.message ?? message;
    }

    return ApiResponse.error(
      message,
      statusCode: response?.statusCode,
      errors: errors,
    );
  }
}
