import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/services/websocket_service.dart';
import '../models/notification.dart';

class NotificationsState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  NotificationsState({
    required this.notifications,
    required this.unreadCount,
    required this.isLoading,
    this.error,
  });

  factory NotificationsState.initial() => NotificationsState(
        notifications: [],
        unreadCount: 0,
        isLoading: false,
      );

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiClient _apiClient = ApiClient();
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription<AppNotification>? _notificationSubscription;

  NotificationsNotifier() : super(NotificationsState.initial()) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    _notificationSubscription?.cancel();
    _notificationSubscription = _webSocketService.notificationStream.listen(
      (notification) {
        // Add new notification at the beginning of the list
        final updatedNotifications = [notification, ...state.notifications];
        state = state.copyWith(
          notifications: updatedNotifications,
          unreadCount: state.unreadCount + 1,
        );
      },
    );
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, error: null);

    final response = await _apiClient.get<Map<String, dynamic>>('/notifications');

    if (response.success && response.data != null) {
      final data = response.data!;
      final notificationsJson = data['data'] as List<dynamic>? ?? [];
      final notifications = notificationsJson
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
      );

      // Also fetch unread count
      await fetchUnreadCount();
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.errorMessage,
      );
    }
  }

  Future<void> fetchUnreadCount() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/notifications/unread-count');

    if (response.success && response.data != null) {
      final count = response.data!['unread_count'] as int? ?? 0;
      state = state.copyWith(unreadCount: count);
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/notifications/$notificationId/read',
    );

    if (response.success) {
      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(read: true, readAt: DateTime.now());
        }
        return n;
      }).toList();

      final newUnreadCount = updatedNotifications.where((n) => !n.read).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      );
      return true;
    }
    return false;
  }

  Future<bool> markAllAsRead() async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/notifications/read-all',
    );

    if (response.success) {
      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        return n.copyWith(read: true, readAt: DateTime.now());
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
      return true;
    }
    return false;
  }

  Future<bool> deleteNotification(int notificationId) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      '/notifications/$notificationId',
    );

    if (response.success) {
      // Remove from local state
      final notification = state.notifications.firstWhere(
        (n) => n.id == notificationId,
        orElse: () => state.notifications.first,
      );
      final wasUnread = !notification.read;

      final updatedNotifications = state.notifications
          .where((n) => n.id != notificationId)
          .toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: wasUnread ? state.unreadCount - 1 : state.unreadCount,
      );
      return true;
    }
    return false;
  }

  void clearNotifications() {
    state = NotificationsState.initial();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier();
});

// Convenience provider for unread count (for badges)
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
