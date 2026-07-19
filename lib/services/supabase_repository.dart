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

  Future<void> addPersonnel(Map<String, dynamic> personnelData) async {
    await _db.from('personnel').insert(personnelData);
  }

  Future<void> deletePersonnel(String armyNo) async {
    await _db.from('personnel').delete().eq('army_no', armyNo);
  }

  Future<void> updatePersonnel(String armyNo, Map<String, dynamic> personnelData) async {
    await _db.from('personnel').update(personnelData).eq('army_no', armyNo);
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
    DateTime? startDate,
    DateTime? endDate,
    String? remarks,
    String? createdBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    
    // 0. Fetch active status to prevent check constraint violations
    final activeStatusResponse = await _db
        .from('status_history')
        .select('start_date')
        .eq('army_no', armyNo)
        .isFilter('end_date', null)
        .maybeSingle();

    String closeDateStr = startDate?.toIso8601String() ?? now;
    if (activeStatusResponse != null) {
      final activeStartDate = DateTime.parse(activeStatusResponse['start_date'] as String);
      final newStartDate = startDate ?? DateTime.now();
      if (newStartDate.isBefore(activeStartDate)) {
        closeDateStr = activeStartDate.toIso8601String();
      }
    }

    // 1. Close current active status
    await _db
        .from('status_history')
        .update({
          'end_date': closeDateStr,
          'updated_at': now,
          'updated_by': createdBy,
        })
        .eq('army_no', armyNo)
        .isFilter('end_date', null);

    // If there is an expected endDate, append it to remarks
    String finalRemarks = remarks ?? '';
    if (endDate != null) {
      final formattedEndDate = endDate.toIso8601String().split('T')[0];
      final returnNote = 'Expected Return: $formattedEndDate';
      if (finalRemarks.isEmpty) {
        finalRemarks = returnNote;
      } else {
        finalRemarks = '$finalRemarks | $returnNote';
      }
    }

    // 2. Insert new active status
    await _db.from('status_history').insert({
      'army_no': armyNo,
      'category': category,
      'subcategory': subcategory,
      'sub_subcategory': subSubcategory,
      'start_date': startDate?.toIso8601String() ?? now,
      'end_date': null, // Must be null for the view v_current_personnel_status to see it as active
      'destination': destination,
      'remarks': finalRemarks.isNotEmpty ? finalRemarks : null,
      'created_by': createdBy,
    });
  }

  /// Updates only the [destination] field on the currently active (end_date IS NULL)
  /// status_history row for [armyNo]. Used when a personnel's location / city
  /// is changed from the profile edit form.
  Future<void> updateStatusDestination({
    required String armyNo,
    required String? destination,
    String? updatedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db
        .from('status_history')
        .update({
          'destination': destination,
          'updated_at': now,
          'updated_by': updatedBy,
        })
        .eq('army_no', armyNo)
        .isFilter('end_date', null);
  }

  Future<List<StatusHistory>> getStatusHistory(String armyNo) async {
    final response = await _db
        .from('status_history')
        .select()
        .eq('army_no', armyNo)
        .order('start_date', ascending: false);

    return (response as List).map((json) => StatusHistory.fromJson(json)).toList();
  }

  Future<List<StatusHistory>> getAllStatusHistory() async {
    final response = await _db
        .from('status_history')
        .select()
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
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> syncStatusHierarchy(Map<String, dynamic> hierarchy) async {
    // Delete existing hierarchy (will cascade to children)
    await _db.from('status_categories').delete().neq('name', '!!!DUMMY!!!');

    for (var mainEntry in hierarchy.entries) {
      final mainName = mainEntry.key;
      final mainRes = await _db.from('status_categories').insert({
        'name': mainName,
        'level': 1,
      }).select().single();
      
      final mainId = mainRes['id'];
      
      final subData = mainEntry.value;
      if (subData is List) {
        for (var subName in subData) {
          await _db.from('status_categories').insert({
            'name': subName,
            'parent_id': mainId,
            'level': 2,
          });
        }
      } else if (subData is Map) {
        for (var subEntry in subData.entries) {
          final subName = subEntry.key;
          await _db.from('status_categories').insert({
            'name': subName,
            'parent_id': mainId,
            'level': 2,
          });
        }
      }
    }
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

    return hierarchy;
  }
}
