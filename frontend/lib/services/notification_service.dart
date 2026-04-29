import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['notification_type'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  WebSocketChannel? _channel;
  final List<AppNotification> _notifications = [];
  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Stream for real-time foreground popups
  final StreamController<AppNotification> _pushStream = StreamController.broadcast();
  Stream<AppNotification> get pushStream => _pushStream.stream;

  Future<void> initialize() async {
    await fetchHistory();
    await _connectWebSocket();
  }

  Future<void> fetchHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await ApiService.get('notifications/', auth: true);
      if (response != null && response is List) {
        _notifications.clear();
        for (var item in response) {
          _notifications.add(AppNotification.fromJson(item));
        }
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to load notifications';
      if (kDebugMode) print('Failed to fetch notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _connectWebSocket() async {
    if (_isConnected) return;
    final token = await ApiService.getAccessToken();
    if (token == null) return;

    final wsBaseUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
    final wsUrl = '$wsBaseUrl/ws/notifications/?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'notification') {
            final newNotif = AppNotification(
              id: DateTime.now().millisecondsSinceEpoch, // fake ID until fetched
              title: data['title'] ?? 'Notification',
              message: data['message'] ?? '',
              type: data['notification_type'] ?? 'system',
              isRead: false,
              createdAt: DateTime.now(),
            );
            _notifications.insert(0, newNotif);
            _pushStream.add(newNotif);
            notifyListeners();
          }
        },
        onDone: () {
          _isConnected = false;
          Future.delayed(const Duration(seconds: 5), _connectWebSocket);
        },
        onError: (e) {
          if (kDebugMode) print('WebSocket Error: $e');
          _isConnected = false;
        },
      );
    } catch (e) {
      if (kDebugMode) print('Failed to connect to WS: $e');
      _isConnected = false;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    // Optimistically update UI first
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final old = _notifications[index];
      _notifications[index] = AppNotification(
        id: old.id,
        title: old.title,
        message: old.message,
        type: old.type,
        isRead: true,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }

    try {
      await ApiService.post('notifications/$notificationId/mark_read/', auth: true);
    } catch (e) {
      // Revert on failure
      if (index != -1) {
        final old = _notifications[index];
        _notifications[index] = AppNotification(
          id: old.id,
          title: old.title,
          message: old.message,
          type: old.type,
          isRead: false,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
      if (kDebugMode) print('Mark as read failed: $e');
    }
  }

  void disposeService() {
    _channel?.sink.close();
    _isConnected = false;
    _notifications.clear();
  }
}
