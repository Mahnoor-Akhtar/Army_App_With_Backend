import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://tuolkvlmaebvsqnzslif.supabase.co';
  final supabaseAnonKey = 'sb_publishable_XCaz-hQWDVJiL7LCO24dtw_5bbi_Gg7';
  
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    final now = DateTime.now().toIso8601String();
    
    // 1. Close current active status
    print('Closing active status...');
    await client
        .from('status_history')
        .update({
          'end_date': now,
          'updated_at': now,
          'updated_by': 'admin',
        })
        .eq('army_no', '64872')
        .filter('end_date', 'is', null);

    print('Inserting new status...');
    // 2. Insert new active status
    await client.from('status_history').insert({
      'army_no': '64872',
      'category': 'Leave',
      'subcategory': 'C/Lve',
      'sub_subcategory': null,
      'start_date': now,
      'end_date': null,
      'destination': 'Test',
      'remarks': 'Testing...',
      'created_by': 'admin',
    });
    
    print('SUCCESS! Inserted successfully.');
  } catch (e) {
    print('ERROR: $e');
  }
}
