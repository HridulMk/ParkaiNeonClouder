import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    _notificationService.fetchHistory();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    setState(() {});
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'booking':
        return Icons.directions_car;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'space':
        return Icons.location_on;
      case 'cancellation':
        return Icons.warning_amber;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'booking':
        return Colors.green;
      case 'wallet':
        return Colors.blue;
      case 'space':
        return Colors.purple;
      case 'cancellation':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notificationService.notifications;
    final isLoading = _notificationService.isLoading;
    final error = _notificationService.error;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _notificationService.fetchHistory(),
            ),
        ],
      ),
      body: _buildBody(notifications, isLoading, error),
    );
  }

  Widget _buildBody(List<AppNotification> notifications, bool isLoading, String? error) {
    // Loading state
    if (isLoading && notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Error state
    if (error != null && notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _notificationService.fetchHistory(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('No notifications yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    // Loading indicator at top when refreshing
    if (isLoading) {
      return Column(
        children: [
          const LinearProgressIndicator(),
          Expanded(child: _buildNotificationList(notifications)),
        ],
      );
    }

    return _buildNotificationList(notifications);
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final isRead = notif.isRead;

                return ColoredBox(
                  color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: _getColorForType(notif.type).withOpacity(0.1),
                      child: Icon(
                        _getIconForType(notif.type),
                        color: _getColorForType(notif.type),
                      ),
                    ),
                    title: Text(
                      notif.title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          notif.message,
                          style: TextStyle(
                            color: Colors.black54,
                            height: 1.3,
                            fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(notif.createdAt),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!isRead) {
                        _notificationService.markAsRead(notif.id);
                      }
                    },
                  ),
                );
              },
            );
  }
}
