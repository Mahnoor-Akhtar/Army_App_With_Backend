import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://tuolkvlmaebvsqnzslif.supabase.co';
  final supabaseAnonKey = 'sb_publishable_XCaz-hQWDVJiL7LCO24dtw_5bbi_Gg7';
  
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    final res = await client.from('v_current_personnel_status').select().eq('army_no', '64872');
    print('v_current_personnel_status: $res');
    
    final res2 = await client.from('status_history').select().eq('army_no', '64872').order('start_date', ascending: false);
    print('status_history: $res2');
  } catch (e) {
    print('ERROR: $e');
  }
}
