import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../../features/admin/presentation/logic/admin_analytics_provider.dart';
import '../../features/admin/presentation/logic/admin_issues_provider.dart';

/// Keeps server-backed admin screens current when another device changes an
/// issue. This is intentionally separate from notifications: it refreshes the
/// actual issue list and dashboard data, not just the badge count.
final liveUpdatesProvider = Provider<LiveUpdatesController>((ref) {
  final controller = LiveUpdatesController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class LiveUpdatesController {
  LiveUpdatesController(this._ref) {
    _startForCurrentUser();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _startForCurrentUser(),
    );
  }

  final Ref _ref;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _refreshDebounce;
  String? _subscribedUserId;

  void _startForCurrentUser() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _channel?.unsubscribe();
      _channel = null;
      _subscribedUserId = null;
      return;
    }
    if (_subscribedUserId == userId && _channel != null) return;

    _channel?.unsubscribe();
    _subscribedUserId = userId;
    _channel = Supabase.instance.client.channel('live-issues:$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'issues',
        callback: (_) => _scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'progress_updates',
        callback: (_) => _scheduleRefresh(),
      )
      ..subscribe();
  }

  /// A progress update can change both tables in quick succession. Debouncing
  /// avoids duplicate network fetches while preserving the current filters.
  void _scheduleRefresh() {
    if (!_ref.read(isAdminProvider)) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      _ref.read(adminIssuesProvider.notifier).fetchIssues();
      _ref.read(adminAnalyticsProvider.notifier).fetchAnalytics();
    });
  }

  void dispose() {
    _refreshDebounce?.cancel();
    _authSubscription?.cancel();
    _channel?.unsubscribe();
  }
}
