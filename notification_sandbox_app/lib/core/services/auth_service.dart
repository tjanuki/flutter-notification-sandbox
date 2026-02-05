import 'dart:io';
import '../../models/user.dart';
import '../network/api_client.dart';
import '../network/api_response.dart';
import '../storage/secure_storage.dart';

class AuthResult {
  final User user;
  final String token;

  AuthResult({required this.user, required this.token});
}

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<ApiResponse<AuthResult>> login(String email, String password) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    if (response.success && response.data != null) {
      final responseData = response.data!;
      final data = responseData['data'] as Map<String, dynamic>;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;

      // Save to secure storage
      await SecureStorage.saveToken(token);
      await SecureStorage.saveUserData(user.toJson());

      return ApiResponse.success(
        AuthResult(user: user, token: token),
        statusCode: response.statusCode,
      );
    }

    return ApiResponse.error(
      response.message ?? 'Login failed',
      statusCode: response.statusCode,
      errors: response.errors,
    );
  }

  Future<ApiResponse<AuthResult>> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    if (response.success && response.data != null) {
      final responseData = response.data!;
      final data = responseData['data'] as Map<String, dynamic>;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;

      // Save to secure storage
      await SecureStorage.saveToken(token);
      await SecureStorage.saveUserData(user.toJson());

      return ApiResponse.success(
        AuthResult(user: user, token: token),
        statusCode: response.statusCode,
      );
    }

    return ApiResponse.error(
      response.message ?? 'Registration failed',
      statusCode: response.statusCode,
      errors: response.errors,
    );
  }

  Future<ApiResponse<void>> logout() async {
    final response = await _apiClient.post<Map<String, dynamic>>('/logout');

    // Clear storage regardless of API response
    await SecureStorage.clearAll();

    if (response.success) {
      return ApiResponse.success(null, statusCode: response.statusCode);
    }

    return ApiResponse.error(
      response.message ?? 'Logout failed',
      statusCode: response.statusCode,
    );
  }

  Future<ApiResponse<User>> getCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/user');

    if (response.success && response.data != null) {
      final responseData = response.data!;
      final data = responseData['data'] as Map<String, dynamic>;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await SecureStorage.saveUserData(user.toJson());
      return ApiResponse.success(user, statusCode: response.statusCode);
    }

    return ApiResponse.error(
      response.message ?? 'Failed to get user',
      statusCode: response.statusCode,
    );
  }

  Future<ApiResponse<User>> updateFcmToken(String fcmToken) async {
    final deviceType = Platform.isAndroid ? 'android' : 'ios';

    final response = await _apiClient.put<Map<String, dynamic>>(
      '/user/fcm-token',
      data: {
        'fcm_token': fcmToken,
        'device_type': deviceType,
      },
    );

    if (response.success && response.data != null) {
      final responseData = response.data!;
      final data = responseData['data'] as Map<String, dynamic>;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await SecureStorage.saveUserData(user.toJson());
      return ApiResponse.success(user, statusCode: response.statusCode);
    }

    return ApiResponse.error(
      response.message ?? 'Failed to update FCM token',
      statusCode: response.statusCode,
    );
  }

  Future<User?> getCachedUser() async {
    final userData = await SecureStorage.getUserData();
    if (userData != null) {
      return User.fromJson(userData);
    }
    return null;
  }

  Future<bool> hasValidSession() async {
    final token = await SecureStorage.getToken();
    return token != null;
  }
}
