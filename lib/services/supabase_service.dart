import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://tuolkvlmaebvsqnzslif.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_XCaz-hQWDVJiL7LCO24dtw_5bbi_Gg7';

  late final SupabaseClient client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    client = Supabase.instance.client;
  }

  SupabaseClient get db => client;
}
