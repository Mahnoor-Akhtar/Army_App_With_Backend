import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/personnel.dart';
import '../models/status_history.dart';
import 'supabase_service.dart';

class SupabaseRepository {
  final SupabaseClient _db = SupabaseService().db;

  Future<List<Personnel>> getAllPersonnel() async {
    final response = await _db
        .from('personnel')
        .select()
        .eq('is_active', true)
        .order('category', ascending: true)
        .order('name', ascending: true);

    return (response as List).map((json) => Personnel.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getCurrentPersonnelStatus() async {
    final response = await _db.from('v_current_personnel_status').select();
    return List<Map<String, dynamic>>.from(response);
  }

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

  Future<List<StatusHistory>> getStatusHistory(String armyNo) async {
    final response = await _db
        .from('status_history')
        .select()
        .eq('army_no', armyNo)
        .order('start_date', ascending: false);

    return (response as List).map((json) => StatusHistory.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomGroups() async {
    final response = await _db.from('v_custom_groups_with_members').select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    final response = await _db.rpc(
      'verify_password',
      params: {'p_username': username, 'p_password': password},
    );

    if (response == null) return null;
    return response as Map<String, dynamic>;
  }

  Future<List<String>> getSystemAttributeItems(String attributeType) async {
    final response = await _db
        .from('system_attributes')
        .select('items')
        .eq('attribute_type', attributeType)
        .maybeSingle();

    if (response == null || response['items'] == null) return [];
    return List<String>.from(response['items'] as List);
  }

  Future<void> updateSystemAttributeItems(String attributeType, List<String> items) async {
    await _db.from('system_attributes').upsert({
      'attribute_type': attributeType,
      'items': items,
    });
  }

  Future<List<Map<String, dynamic>>> getStatusCategories() async {
    final response = await _db
        .from('status_categories')
        .select()
        .order('level', ascending: true)
        .order('sort_order', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getStatusHierarchy() async {
    final categories = await getStatusCategories();
    final hierarchy = <String, dynamic>{};

    // First, create a map for ID lookup
    final idToName = <String, String>{};
    for (var cat in categories) {
      idToName[cat['id'] as String] = cat['name'] as String;
    }

    // Level 1: main categories
    for (var cat in categories.where((c) => c['level'] == 1)) {
      final name = cat['name'] as String;
      hierarchy[name] = null;
    }

    // Level 2: subcategories
    for (var cat in categories.where((c) => c['level'] == 2)) {
      final parentId = cat['parent_id'] as String?;
      if (parentId == null) continue;
      final parentName = idToName[parentId];
      if (parentName == null) continue;

      if (hierarchy[parentName] == null) {
        hierarchy[parentName] = <String>[];
      }
      if (hierarchy[parentName] is List<String>) {
        (hierarchy[parentName] as List<String>).add(cat['name'] as String);
      }
    }

    // Level 3: sub-subcategories
    for (var cat in categories.where((c) => c['level'] == 3)) {
      final parentId = cat['parent_id'] as String?;
      if (parentId == null) continue;
      final parentName = idToName[parentId];
      if (parentName == null) continue;

      // Find grandparent
      String? grandparentName;
      for (var level2Cat in categories.where((c) => c['level'] == 2)) {
        if (level2Cat['id'] == parentId) {
          final level2ParentId = level2Cat['parent_id'] as String?;
          if (level2ParentId != null) {
            grandparentName = idToName[level2ParentId];
          }
        }
      }
      if (grandparentName == null) continue;

      // Convert parent's data to map if it's a list
      if (hierarchy[grandparentName] is List<String>) {
        final tempList = hierarchy[grandparentName] as List<String>;
        final tempMap = <String, List<String>>{};
        for (var sub in tempList) {
          tempMap[sub] = [];
        }
        hierarchy[grandparentName] = tempMap;
      }

      if (hierarchy[grandparentName] is Map<String, dynamic>) {
        final subMap = hierarchy[grandparentName] as Map<String, dynamic>;
        if (!subMap.containsKey(parentName)) {
          subMap[parentName] = <String>[];
        }
        if (subMap[parentName] is List<String>) {
          (subMap[parentName] as List<String>).add(cat['name'] as String);
        }
      }
    }

    return hierarchy;
  }
}
