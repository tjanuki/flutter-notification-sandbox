class AppNotification {
  final int id;
  final int notificationId;
  final String title;
  final String body;
  final String senderName;
  final bool read;
  final DateTime? readAt;
  final DateTime sentAt;

  AppNotification({
    required this.id,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.senderName,
    required this.read,
    this.readAt,
    required this.sentAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    // Handle both direct response and nested notification structure
    final notification = json['notification'] as Map<String, dynamic>?;
    final sender = notification?['sender'] as Map<String, dynamic>?;

    return AppNotification(
      id: json['id'] as int,
      notificationId: json['notification_id'] as int,
      title: notification?['title'] as String? ?? json['title'] as String? ?? '',
      body: notification?['body'] as String? ?? json['body'] as String? ?? '',
      senderName: sender?['name'] as String? ?? json['sender_name'] as String? ?? 'Unknown',
      read: json['read'] == true || json['read'] == 1,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : DateTime.now(),
    );
  }

  factory AppNotification.fromWebSocket(Map<String, dynamic> json) {
    // WebSocket events may have a different structure
    return AppNotification(
      id: json['user_notification_id'] as int? ?? json['id'] as int? ?? 0,
      notificationId: json['notification_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? 'Unknown',
      read: false,
      readAt: null,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notification_id': notificationId,
      'title': title,
      'body': body,
      'sender_name': senderName,
      'read': read,
      'read_at': readAt?.toIso8601String(),
      'sent_at': sentAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    int? id,
    int? notificationId,
    String? title,
    String? body,
    String? senderName,
    bool? read,
    DateTime? readAt,
    DateTime? sentAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      title: title ?? this.title,
      body: body ?? this.body,
      senderName: senderName ?? this.senderName,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}
