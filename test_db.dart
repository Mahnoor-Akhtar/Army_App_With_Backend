import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://tuolkvlmaebvsqnzslif.supabase.co';
  final supabaseAnonKey = 'sb_publishable_XCaz-hQWDVJiL7LCO24dtw_5bbi_Gg7';
  
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    final res = await client.from('status_history').select('created_by').limit(1);
    print('SUCCESS: created_by column exists! $res');
  } catch (e) {
    print('ERROR checking created_by: $e');
  }

  try {
    final res = await client.from('status_history').select('updated_by').limit(1);
    print('SUCCESS: updated_by column exists! $res');
  } catch (e) {
    print('ERROR checking updated_by: $e');
  }
}
