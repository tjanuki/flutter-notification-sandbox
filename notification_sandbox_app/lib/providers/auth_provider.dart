import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/services/auth_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/websocket_service.dart';
import '../core/storage/secure_storage.dart';
import '../models/user.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  AuthState({
    required this.status,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(User user) =>
      AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.unauthenticated([String? error]) =>
      AuthState(status: AuthStatus.unauthenticated, error: error);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();
  final WebSocketService _webSocketService = WebSocketService();
  final PushNotificationService _pushService = PushNotificationService();
  StreamSubscription<String>? _tokenSubscription;

  AuthNotifier() : super(AuthState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = AuthState.loading();

    // Set up API client unauthorized callback
    ApiClient().setUnauthorizedCallback(_handleUnauthorized);

    // Check for existing session
    final hasSession = await _authService.hasValidSession();
    if (hasSession) {
      // Try to get cached user first
      final cachedUser = await _authService.getCachedUser();
      if (cachedUser != null) {
        state = AuthState.authenticated(cachedUser);
        await _onLoginSuccess(cachedUser);

        // Refresh user data from API in background
        _refreshUserData();
      } else {
        // No cached user, try to fetch from API
        final response = await _authService.getCurrentUser();
        if (response.success && response.data != null) {
          state = AuthState.authenticated(response.data!);
          await _onLoginSuccess(response.data!);
        } else {
          state = AuthState.unauthenticated();
        }
      }
    } else {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> _refreshUserData() async {
    final response = await _authService.getCurrentUser();
    if (response.success && response.data != null) {
      state = state.copyWith(user: response.data);
    }
  }

  void _handleUnauthorized() {
    _webSocketService.disconnect();
    state = AuthState.unauthenticated('Session expired');
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();

    final response = await _authService.login(email, password);
    if (response.success && response.data != null) {
      final user = response.data!.user;
      state = AuthState.authenticated(user);
      await _onLoginSuccess(user);
      return true;
    } else {
      state = AuthState.unauthenticated(response.errorMessage);
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    state = AuthState.loading();

    final response = await _authService.register(
      name,
      email,
      password,
      passwordConfirmation,
    );
    if (response.success && response.data != null) {
      final user = response.data!.user;
      state = AuthState.authenticated(user);
      await _onLoginSuccess(user);
      return true;
    } else {
      state = AuthState.unauthenticated(response.errorMessage);
      return false;
    }
  }

  Future<void> _onLoginSuccess(User user) async {
    // Connect to WebSocket
    try {
      await _webSocketService.connect(user.id);
    } catch (e) {
      // WebSocket connection failed, but continue
    }

    // Register FCM token
    await _registerFcmToken();

    // Listen for token refresh
    _tokenSubscription?.cancel();
    _tokenSubscription = _pushService.tokenStream.listen((token) {
      _authService.updateFcmToken(token);
    });
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await _pushService.getToken();
      if (token != null) {
        await _authService.updateFcmToken(token);
      }
    } catch (e) {
      // FCM token registration failed
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();

    // Disconnect WebSocket
    await _webSocketService.disconnect();

    // Cancel token subscription
    _tokenSubscription?.cancel();
    _tokenSubscription = null;

    // Call logout API
    await _authService.logout();

    // Clear storage
    await SecureStorage.clearAll();

    state = AuthState.unauthenticated();
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
