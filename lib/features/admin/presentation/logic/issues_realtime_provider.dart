import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_analytics_provider.dart';
import 'admin_issues_provider.dart';
import 'admin_issue_detail_provider.dart';

// ---------------------------------------------------------------------------
// SHARED REALTIME — Issues table watcher (diagnostic build)
// ---------------------------------------------------------------------------
// Opens ONE Supabase realtime channel on the `issues` table.
// On every INSERT or UPDATE it calls fetchAnalytics() and fetchIssues() so
// both the Dashboard and the Verify/Issue List refresh automatically.
//
// REQUIREMENTS (server-side):
//   ALTER PUBLICATION supabase_realtime ADD TABLE public.issues;
//
// Usage: ref.watch(issuesRealtimeProvider) in any ConsumerWidget.
// ---------------------------------------------------------------------------

class _IssuesRealtimeNotifier extends AsyncNotifier<void> {
  RealtimeChannel? _channel;

  @override
  Future<void> build() async {
    debugPrint('[REALTIME] ▶ build() started — creating channel');

    // Keep alive for the whole session.
    ref.keepAlive();

    ref.onDispose(() {
      debugPrint('[REALTIME] ♻ onDispose() — removing channel');
      final ch = _channel;
      _channel = null;
      if (ch != null) {
        Supabase.instance.client.removeChannel(ch);
      }
    });

    final client = Supabase.instance.client;

    debugPrint('REALTIME CHANNEL CREATED');
    _channel = client
        .channel('admin_issues_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'issues',
          callback: (payload) {
            debugPrint('REALTIME EVENT RECEIVED');
            debugPrint('TABLE NAME: issues');
            debugPrint('EVENT TYPE: ${payload.eventType}');
            final issueId =
                payload.newRecord['id'] as String? ??
                payload.oldRecord['id'] as String?;
            debugPrint('RECORD ID: $issueId');

            _refresh();

            if (issueId != null) {
              ref
                  .read(adminIssueDetailProvider(issueId).notifier)
                  .fetchDetail();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'progress_updates',
          callback: (payload) {
            debugPrint('REALTIME EVENT RECEIVED');
            debugPrint('TABLE NAME: progress_updates');
            debugPrint('EVENT TYPE: ${payload.eventType}');
            final issueId =
                payload.newRecord['issue_id'] as String? ??
                payload.oldRecord['issue_id'] as String?;
            debugPrint('RECORD ID: $issueId');

            _refresh();

            if (issueId != null) {
              ref
                  .read(adminIssueDetailProvider(issueId).notifier)
                  .fetchDetail();
            }
          },
        );

    _channel!.subscribe((RealtimeSubscribeStatus status, [Object? error]) {
      debugPrint('REALTIME SUBSCRIPTION STATUS: $status');
      if (error != null) debugPrint('REALTIME ERROR: $error');

      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        final ch = _channel;
        _channel = null;
        if (ch != null) {
          Supabase.instance.client.removeChannel(ch);
        }
      }
    });

    debugPrint('[REALTIME] ▶ build() complete — channel reference: $_channel');
  }

  Future<void> _refresh() async {
    debugPrint('[DIAGNOSTIC] Step 1: _refresh() executing');
    debugPrint(
      '[REALTIME] 🔄 _refresh() called — triggering fetchAnalytics + fetchIssues',
    );

    // Add micro-delay to prevent PostgREST race condition where queries execute before transaction commits
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      debugPrint(
        '[DIAGNOSTIC] Step 2: Reading adminAnalyticsProvider.notifier to call fetchAnalytics',
      );
      ref.read(adminAnalyticsProvider.notifier).fetchAnalytics(silent: true);
      debugPrint('[REALTIME] 🔄 fetchAnalytics() invoked');
    } catch (e) {
      debugPrint('[REALTIME] ❌ fetchAnalytics() threw: $e');
    }
    try {
      ref.read(adminIssuesProvider.notifier).fetchIssues(silent: true);
      debugPrint('[REALTIME] 🔄 fetchIssues() invoked');
    } catch (e) {
      debugPrint('[REALTIME] ❌ fetchIssues() threw: $e');
    }
  }
}

/// Watch this provider in any admin screen that should react to `issues` changes.
final issuesRealtimeProvider =
    AsyncNotifierProvider<_IssuesRealtimeNotifier, void>(
      _IssuesRealtimeNotifier.new,
    );
