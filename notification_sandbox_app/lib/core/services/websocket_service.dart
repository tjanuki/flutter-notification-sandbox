import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../../config/api_config.dart';
import '../../config/reverb_config.dart';
import '../../models/notification.dart';
import '../storage/secure_storage.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  PusherChannelsFlutter? _pusher;
  PusherChannel? _userChannel;
  bool _isConnected = false;
  int? _currentUserId;

  final _notificationController = StreamController<AppNotification>.broadcast();
  Stream<AppNotification> get notificationStream => _notificationController.stream;

  final _connectionStateController = StreamController<String>.broadcast();
  Stream<String> get connectionStateStream => _connectionStateController.stream;

  WebSocketService._internal();

  Future<void> connect(int userId) async {
    if (_isConnected && _currentUserId == userId) {
      return;
    }

    // Disconnect existing connection if different user
    if (_isConnected && _currentUserId != userId) {
      await disconnect();
    }

    _currentUserId = userId;

    try {
      _pusher = PusherChannelsFlutter.getInstance();

      await _pusher!.init(
        apiKey: ReverbConfig.appKey,
        cluster: ReverbConfig.cluster,
        onConnectionStateChange: _onConnectionStateChange,
        onError: _onError,
        onAuthorizer: _onAuthorizer,
      );

      await _pusher!.connect();
    } catch (e) {
      _connectionStateController.add('error');
      rethrow;
    }
  }

  Future<void> _subscribeToUserChannel() async {
    if (_pusher == null || _currentUserId == null) return;

    final channelName = 'private-user.$_currentUserId';

    try {
      _userChannel = await _pusher!.subscribe(
        channelName: channelName,
        onEvent: _onEvent,
        onSubscriptionSucceeded: (data) {
          // Subscription successful
        },
        onSubscriptionError: (message, e) {
          _connectionStateController.add('subscription_error');
        },
      );
    } catch (e) {
      _connectionStateController.add('subscription_error');
    }
  }

  void _onConnectionStateChange(String currentState, String previousState) {
    _connectionStateController.add(currentState);

    if (currentState == 'CONNECTED') {
      _isConnected = true;
      _subscribeToUserChannel();
    } else if (currentState == 'DISCONNECTED') {
      _isConnected = false;
    }
  }

  void _onError(String message, int? code, dynamic e) {
    _connectionStateController.add('error');
  }

  Future<Map<String, dynamic>> _onAuthorizer(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    final token = await SecureStorage.getToken();

    if (token == null) {
      throw Exception('No auth token available');
    }

    // Make authorization request to Laravel backend
    try {
      final uri = Uri.parse(ApiConfig.broadcastingAuthUrl);
      final response = await _makeAuthRequest(
        uri,
        {
          'socket_id': socketId,
          'channel_name': channelName,
        },
        token,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _makeAuthRequest(
    Uri uri,
    Map<String, String> body,
    String token,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);

      request.headers.set('Accept', 'application/json');
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      request.headers.set('Authorization', 'Bearer $token');

      final bodyString = body.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      request.write(bodyString);

      final response = await request.close();
      final responseBody = await response.transform(const Utf8Decoder()).join();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      } else {
        throw Exception('Auth failed: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  void _onEvent(PusherEvent event) {
    if (event.eventName == 'NotificationSent' ||
        event.eventName == 'App\\Events\\NotificationSent') {
      try {
        final data = _decodeEventData(event.data);
        if (data != null) {
          final notification = AppNotification.fromWebSocket(data);
          _notificationController.add(notification);
        }
      } catch (e) {
        // Error parsing notification
      }
    }
  }

  Map<String, dynamic>? _decodeEventData(String? data) {
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> disconnect() async {
    if (_userChannel != null && _currentUserId != null) {
      try {
        await _pusher?.unsubscribe(channelName: 'private-user.$_currentUserId');
      } catch (e) {
        // Ignore unsubscribe errors
      }
      _userChannel = null;
    }

    try {
      await _pusher?.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    }

    _isConnected = false;
    _currentUserId = null;
    _pusher = null;
  }

  bool get isConnected => _isConnected;

  void dispose() {
    _notificationController.close();
    _connectionStateController.close();
    disconnect();
  }
}
