import 'dart:io';
import 'package:supabase/supabase.dart';

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
    ).subscribe((status, [error]) {
      print('Subscription status: ' + status.toString());
      if (error != null) print('Error: ' + error.toString());
      
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('Successfully subscribed, waiting 5 seconds...');
        Future.delayed(Duration(seconds: 5), () => exit(0));
      } else {
        exit(1);
      }
    });
  } catch (e) {
    print('Failed: ' + e.toString());
    exit(1);
  }
}
