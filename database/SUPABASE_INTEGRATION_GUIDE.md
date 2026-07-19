# Supabase Integration Guide

## Step 1: Add Supabase Dependencies

Update your `pubspec.yaml` to include Supabase packages:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.5.5
  csv: ^8.0.0
  path_provider: ^2.1.6
  pdf: ^3.13.0
  provider: ^6.1.5+1
  open_file: ^3.5.0
  url_launcher: ^6.2.0
  image_picker: ^1.2.3
  
  # Supabase packages
  supabase_flutter: ^2.8.3
  supabase: ^2.3.2
```

Then run:
```bash
flutter pub get
```

## Step 2: Set Up Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Wait for the project to initialize
3. Go to **SQL Editor** → **New Query**
4. Copy and paste the contents of `comprehensive_schema.sql`
5. Run the query to create all tables and seed data
6. Go to **Project Settings** → **API** and copy your:
   - Project URL
   - Anon/Public Key

## Step 3: Initialize Supabase in Your App

Create a new file `lib/services/supabase_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

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
```

**Replace** `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with your actual values.

## Step 4: Update Main.dart

Modify `lib/main.dart` to initialize Supabase:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart'; // Add this
import 'services/personnel_data_manager.dart';
import 'views/splash_screen.dart';
import 'views/login_screen.dart';
import 'views/dashboard_screen.dart';
import 'viewmodels/app_viewmodel.dart';
import 'viewmodels/login_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/nominal_roll_viewmodel.dart';
import 'viewmodels/analysis_viewmodel.dart';
import 'viewmodels/edit_tab_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseService().initialize();
  
  final prefs = await SharedPreferences.getInstance();
  PersonnelDataManager().init(prefs);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppViewModel()),
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => NominalRollViewModel()),
        ChangeNotifierProvider(create: (_) => AnalysisViewModel()),
        ChangeNotifierProvider(create: (_) => EditTabViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

// ... rest of your main.dart code
```

## Step 5: Create Data Models for Supabase

Create `lib/models/personnel.dart`:

```dart
class Personnel {
  final String armyNo;
  final String rank;
  final String name;
  final String category;
  final String cl;
  final String? trade;
  final String? battery;
  final String? contactNo;
  final String? remarks;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Personnel({
    required this.armyNo,
    required this.rank,
    required this.name,
    required this.category,
    required this.cl,
    this.trade,
    this.battery,
    this.contactNo,
    this.remarks,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Personnel.fromJson(Map<String, dynamic> json) {
    return Personnel(
      armyNo: json['army_no'] as String,
      rank: json['rank'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      cl: json['cl'] as String,
      trade: json['trade'] as String?,
      battery: json['battery'] as String?,
      contactNo: json['contact_no'] as String?,
      remarks: json['remarks'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'army_no': armyNo,
      'rank': rank,
      'name': name,
      'category': category,
      'cl': cl,
      'trade': trade,
      'battery': battery,
      'contact_no': contactNo,
      'remarks': remarks,
      'is_active': isActive,
    };
  }
}
```

Create `lib/models/status_history.dart`:

```dart
class StatusHistory {
  final String id;
  final String armyNo;
  final String category;
  final String? subcategory;
  final String? subSubcategory;
  final DateTime startDate;
  final DateTime? endDate;
  final String? destination;
  final String? remarks;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  StatusHistory({
    required this.id,
    required this.armyNo,
    required this.category,
    this.subcategory,
    this.subSubcategory,
    required this.startDate,
    this.endDate,
    this.destination,
    this.remarks,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    return StatusHistory(
      id: json['id'] as String,
      armyNo: json['army_no'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      subSubcategory: json['sub_subcategory'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      destination: json['destination'] as String?,
      remarks: json['remarks'] as String?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
```

## Step 6: Create a Supabase Data Repository

Create `lib/services/supabase_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/personnel.dart';
import '../models/status_history.dart';
import 'supabase_service.dart';

class SupabaseRepository {
  final SupabaseClient _db = SupabaseService().db;

  // Get all personnel
  Future<List<Personnel>> getAllPersonnel() async {
    final response = await _db
        .from('personnel')
        .select()
        .eq('is_active', true)
        .order('category', ascending: true)
        .order('name', ascending: true);
    
    return (response as List).map((json) => Personnel.fromJson(json)).toList();
  }

  // Get current status for all personnel
  Future<List<Map<String, dynamic>>> getCurrentPersonnelStatus() async {
    final response = await _db.from('v_current_personnel_status').select();
    return List<Map<String, dynamic>>.from(response);
  }

  // Update personnel status
  Future<void> updatePersonnelStatus({
    required String armyNo,
    required String category,
    String? subcategory,
    String? subSubcategory,
    String? destination,
    String? remarks,
    String? createdBy,
  }) async {
    await _db.rpc('update_personnel_status', params: {
      'p_army_no': armyNo,
      'p_category': category,
      'p_subcategory': subcategory,
      'p_sub_subcategory': subSubcategory,
      'p_destination': destination,
      'p_remarks': remarks,
      'p_created_by': createdBy,
    });
  }

  // Get status history for a person
  Future<List<StatusHistory>> getStatusHistory(String armyNo) async {
    final response = await _db
        .from('status_history')
        .select()
        .eq('army_no', armyNo)
        .order('start_date', ascending: false);
    
    return (response as List).map((json) => StatusHistory.fromJson(json)).toList();
  }

  // Get all custom groups
  Future<List<Map<String, dynamic>>> getCustomGroups() async {
    final response = await _db.from('v_custom_groups_with_members').select();
    return List<Map<String, dynamic>>.from(response);
  }

  // Authenticate user
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    // Note: In production, use Supabase Auth instead of custom command_slots
    final response = await _db
        .from('command_slots')
        .select()
        .eq('username', username)
        .eq('is_active', true)
        .maybeSingle();
    
    if (response == null) return null;
    
    // TODO: Implement proper password hashing verification
    // For demo purposes only - DO NOT USE IN PRODUCTION!
    return response;
  }
}
```

## Step 7: Add PostgreSQL Function for Status Update

Add this function to your Supabase SQL Editor:

```sql
CREATE OR REPLACE FUNCTION update_personnel_status(
    p_army_no VARCHAR,
    p_category VARCHAR,
    p_subcategory VARCHAR DEFAULT NULL,
    p_sub_subcategory VARCHAR DEFAULT NULL,
    p_destination VARCHAR DEFAULT NULL,
    p_remarks TEXT DEFAULT NULL,
    p_created_by VARCHAR DEFAULT NULL,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Close current active status
    UPDATE status_history
    SET end_date = NOW(),
        updated_by = p_created_by,
        updated_at = NOW()
    WHERE army_no = p_army_no AND end_date IS NULL;
    
    -- Insert new active status
    INSERT INTO status_history (
        army_no, category, subcategory, sub_subcategory, 
        start_date, end_date, destination, remarks, created_by
    ) VALUES (
        p_army_no, p_category, p_subcategory, p_sub_subcategory,
        COALESCE(p_start_date, NOW()), p_end_date, p_destination, p_remarks, p_created_by
    );

    -- Update personnel table attributes
    UPDATE personnel
    SET status_category = p_category,
        status_subcategory = p_subcategory,
        status_start_date = COALESCE(p_start_date, NOW()),
        status_end_date = p_end_date,
        updated_at = NOW()
    WHERE army_no = p_army_no;
END;
$$ LANGUAGE plpgsql;
```

## Step 8: Security Best Practices

### Important:
1. **Never store plain text passwords!**
2. Use Supabase Auth instead of custom `command_slots` for production
3. Enable RLS policies properly
4. Use environment variables for API keys
5. Never commit API keys to version control

### For Production:
- Use Supabase Auth with email/password or OAuth
- Implement proper password hashing (bcrypt/Argon2)
- Add rate limiting
- Enable email verification

## Next Steps

1. Replace all `SharedPreferences` calls with Supabase calls
2. Update your ViewModels to use `SupabaseRepository`
3. Implement real-time subscriptions for live updates
4. Add offline support with local caching
5. Implement proper error handling

## Resources

- [Supabase Flutter Documentation](https://supabase.com/docs/reference/dart/introduction)
- [Supabase SQL Documentation](https://supabase.com/docs/guides/database/overview)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
