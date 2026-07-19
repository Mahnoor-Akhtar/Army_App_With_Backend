import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://tuolkvlmaebvsqnzslif.supabase.co';
  final supabaseAnonKey = 'sb_publishable_XCaz-hQWDVJiL7LCO24dtw_5bbi_Gg7';
  
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    // Instead of querying the view, we query personnel and join manually to see what's wrong.
    final pRes = await client.from('personnel').select().eq('army_no', '64872');
    print('personnel: $pRes');
  } catch (e) {
    print('ERROR: $e');
  }
}
