import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://tuolkvlmaebvsqnzslif.supabase.co';
  final supabaseAnonKey = 'sb_publishable_XCaz-hQWDVJiL7LCO24dtw_5bbi_Gg7';
  
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    final res = await client.from('status_history').select('id, army_no, category, end_date').eq('army_no', '64872').isFilter('end_date', null);
    print('Active statuses for 64872: $res');
    
    // Check view definition if possible
  } catch (e) {
    print('ERROR: $e');
  }
}
