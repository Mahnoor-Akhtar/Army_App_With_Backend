import 'package:supabase/supabase.dart';
void main() async {
  final client = SupabaseClient('https://tuolkvlmaebvsqnzslif.supabase.co', 'sb_publishable_XCaz-hQWDVJiL7LCO24dtw_5bbi_Gg7');
  final res = await client.from('v_current_personnel_status').select('status_remarks, remarks').eq('army_no', '64872');
  print('Result: $res');
}
