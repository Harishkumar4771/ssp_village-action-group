import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../features/issues/data/data_sources/issue_local_data_source.dart';
import '../../features/issues/data/data_sources/progress_update_local_data_source.dart';
import '../../features/issues/data/remote/issue_remote_data_source.dart';
import '../../features/issues/data/remote/progress_update_remote_data_source.dart';
import '../../features/meetings/data/data_sources/meeting_local_data_source.dart';
import '../../features/villages/data/data_sources/village_local_data_source.dart';
import '../database/local_db.dart';
import 'sync_status.dart';

/// Manages background synchronization when the device comes online.
/// On web, this is a no-op since offline sync is handled differently.
class SyncManager {
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _isSyncing = false;

  /// Starts listening for network changes to trigger background sync.
  static void initialize() {
    if (!LocalDb.isAvailable) return;

    final connectivity = Connectivity();
    _subscription = connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _processSyncQueue();
      }
    });
  }

  static Future<void> syncNow() async {
    if (!LocalDb.isAvailable) return;
    debugPrint(
      'SyncManager: Manual sync triggered. Processing pending queue...',
    );
    await _processSyncQueue();
  }

  static Future<void> _processSyncQueue() async {
    if (!LocalDb.isAvailable) return;
    if (_isSyncing) return;
    _isSyncing = true;
    debugPrint('SyncManager: Network connected. Processing pending queue...');

    final isar = LocalDb.instance;
    if (isar == null) return;

    try {
      // 1. Sync Issues. A first-time insert fires the database notification
      // trigger; retries are safe because the remote write is an upsert.
      final issueDs = IssueLocalDataSource();
      final issueRemoteDs = IssueRemoteDataSource();
      final pendingIssues = await issueDs.getPendingSyncIssues();
      for (final issue in pendingIssues) {
        debugPrint('Syncing issue: ${issue.id} ...');
        await issueRemoteDs.upsertIssue(issue);
        issue.syncStatus = SyncStatus.synced;
        await issueDs.saveIssue(issue);
      }

      // 2. Progress updates must follow their parent issue so the foreign key
      // is valid. New rows trigger their own live notification.
      final progressDs = ProgressUpdateLocalDataSource();
      final progressRemoteDs = ProgressUpdateRemoteDataSource();
      final pendingUpdates = await progressDs.getPendingSyncUpdates();
      for (final update in pendingUpdates) {
        final parentIssue = await issueDs.getIssueById(update.issueId);
        if (parentIssue?.syncStatus != SyncStatus.synced) continue;
        debugPrint('Syncing progress update: ${update.id} ...');
        await progressRemoteDs.upsertProgressUpdate(update);
        update.syncStatus = SyncStatus.synced;
        await progressDs.saveUpdate(update);
      }

      // 3. Sync Meetings
      final meetingDs = MeetingLocalDataSource();
      final pendingMeetings = await meetingDs.getPendingSyncMeetings();
      for (final meeting in pendingMeetings) {
        debugPrint('Syncing meeting: ${meeting.id} ...');
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Simulate API call
        meeting.syncStatus = SyncStatus.synced;
        await meetingDs.saveMeeting(meeting);
      }

      // 4. Sync Villages
      final villageDs = VillageLocalDataSource();
      final pendingVillages = await villageDs.getPendingSyncVillages();
      for (final village in pendingVillages) {
        debugPrint('Syncing village: ${village.id} ...');
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Simulate API call
        village.syncStatus = SyncStatus.synced;
        await villageDs.saveVillage(village);
      }

      debugPrint('SyncManager: Queue processing complete.');
    } catch (e) {
      debugPrint('SyncManager: Error processing queue: $e');
    } finally {
      _isSyncing = false;
    }
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
