import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/notification_model.dart';

class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;

  NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class NotificationService extends StateNotifier<NotificationState> {
  RealtimeChannel? _channel;
  
  NotificationService() : super(NotificationState()) {
    _init();
  }

  void _init() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _fetchInitialNotifications();
      _subscribeToNotifications();
    }

    // Listen to auth changes (login/logout)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _fetchInitialNotifications();
        _subscribeToNotifications();
      } else {
        _channel?.unsubscribe();
        state = NotificationState(); // clear state on logout
      }
    });
  }

  Future<void> _fetchInitialNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      final List<NotificationModel> notifs = (response as List<dynamic>)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(notifications: notifs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _subscribeToNotifications() {
    _channel?.unsubscribe();
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    _channel = Supabase.instance.client.channel('public:notifications');
    _channel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          _handleRealtimeUpdate(payload);
        },
      )
      .subscribe();
  }

  void _handleRealtimeUpdate(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert) {
      final newNotif = NotificationModel.fromJson(payload.newRecord);
      state = state.copyWith(
        notifications: [newNotif, ...state.notifications],
      );
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final updatedNotif = NotificationModel.fromJson(payload.newRecord);
      final updatedList = state.notifications.map((n) {
        return n.id == updatedNotif.id ? updatedNotif : n;
      }).toList();
      state = state.copyWith(notifications: updatedList);
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final deletedId = payload.oldRecord['id'];
      final updatedList = state.notifications.where((n) => n.id != deletedId).toList();
      state = state.copyWith(notifications: updatedList);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      // Optimistic update
      final currentNotifs = List<NotificationModel>.from(state.notifications);
      final index = currentNotifs.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final notif = currentNotifs[index];
        currentNotifs[index] = NotificationModel(
          id: notif.id,
          userId: notif.userId,
          title: notif.title,
          message: notif.message,
          isRead: true,
          createdAt: notif.createdAt,
        );
        state = state.copyWith(notifications: currentNotifs);
      }

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      // Handle error (maybe revert optimistic update)
      state = state.copyWith(error: e.toString());
      _fetchInitialNotifications(); // revert
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final currentNotifs = state.notifications.map((n) {
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          title: n.title,
          message: n.message,
          isRead: true,
          createdAt: n.createdAt,
        );
      }).toList();
      state = state.copyWith(notifications: currentNotifs);

      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      _fetchInitialNotifications(); // revert
    }
  }
}

final notificationServiceProvider = StateNotifierProvider<NotificationService, NotificationState>((ref) {
  return NotificationService();
});
