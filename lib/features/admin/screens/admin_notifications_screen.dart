import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/services/notification_service.dart';

/// Live issue notifications for administrators and supervisors.
class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationServiceProvider);
    final notifier = ref.read(notificationServiceProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: notifier.markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
          ? const Center(child: Text('No issue notifications yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = state.notifications[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        notification.isRead
                            ? Icons.notifications_none
                            : Icons.notifications,
                      ),
                    ),
                    title: Text(notification.title),
                    subtitle: Text(notification.message),
                    trailing: notification.isRead
                        ? null
                        : const Icon(
                            Icons.circle,
                            size: 10,
                            color: Color(0xFF2E7D32),
                          ),
                    onTap: () => notifier.markAsRead(notification.id),
                  ),
                );
              },
            ),
    );
  }
}
