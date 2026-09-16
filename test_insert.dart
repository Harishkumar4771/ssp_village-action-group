import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

void main() async {
  final supabase = SupabaseClient('https://qbshdypvckqppbhxaneh.supabase.co', 'sb_publishable_qLBDLp0WGEEscPcx8NiG0A_MSrser4B');
  
  try {
    print('Checking realtime subscription...');
    final channel = supabase.channel('test_channel');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      callback: (payload) {
        print('Event received: ' + payload.toString());
      }
    ).subscribe((status, [error]) async {
      print('Subscription status: ' + status.toString());
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('Successfully subscribed, waiting 1s before insert...');
        await Future.delayed(Duration(seconds: 1));
        
        final testId = Uuid().v4();
        print('Inserting test issue...');
        
        // We need valid leader_id, village_id, category_id.
        // Let's just fetch one.
        final leader = await supabase.from('profiles').select('id').eq('role', 'VAG Leader').limit(1).single();
        final village = await supabase.from('villages').select('id').limit(1).single();
        final category = await supabase.from('issue_categories').select('id').limit(1).single();
        
        await supabase.from('issues').insert({
          'id': testId,
          'title': 'Realtime Test',
          'description': 'Testing realtime event',
          'status': 'reported',
          'leader_id': leader['id'],
          'village_id': village['id'],
          'category_id': category['id'],
          'current_progress': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String()
        });
        print('Insert complete. Waiting 3s for event...');
        await Future.delayed(Duration(seconds: 3));
        
        print('Cleaning up...');
        await supabase.from('issues').delete().eq('id', testId);
        exit(0);
      }
    });
  } catch (e) {
    print('Failed: ' + e.toString());
    exit(1);
  }
}
