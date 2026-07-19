import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://tuolkvlmaebvsqnzslif.supabase.co';
  final supabaseAnonKey = 'sb_publishable_XCaz-hQWDVJiL7LCO24dtw_5bbi_Gg7';
  
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    final res = await client.from('v_current_personnel_status').select('army_no, current_category, current_subcategory, start_date, end_date').eq('army_no', '64872');
    print('v_current_personnel_status (no photo): $res');
  } catch (e) {
    print('ERROR: $e');
  }
}
