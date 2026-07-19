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
    print('SupabaseRepository.authenticateUser: Calling verify_password with username: $username');
    try {
      final response = await _db.rpc(
        'verify_password',
        params: {'p_username': username, 'p_password': password},
      );

      print('SupabaseRepository.authenticateUser: Response: $response');

      if (response == null) {
        print('SupabaseRepository.authenticateUser: Response is null');
        return null;
      }
      return response as Map<String, dynamic>;
    } catch (e, stackTrace) {
      print('SupabaseRepository.authenticateUser: Error: $e');
      print('SupabaseRepository.authenticateUser: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateSlotCredentials(int slotId, String armyNo, String username, String plainPassword, String role) async {
    await _db.from('command_slots').update({
      'army_no': armyNo.isEmpty ? null : armyNo,
      'username': username,
      'password_hash': plainPassword,
      'role': role,
    }).eq('slot_id', slotId);
  }

  Future<Map<String, dynamic>?> changePassword(String username, String oldPassword, String newPassword) async {
    print('SupabaseRepository.changePassword: Calling change_password for username: $username');
    try {
      final response = await _db.rpc(
        'change_password',
        params: {
          'p_username': username,
          'p_old_password': oldPassword,
          'p_new_password': newPassword,
        },
      );

      print('SupabaseRepository.changePassword: Response: $response');

      if (response == null) {
        print('SupabaseRepository.changePassword: Response is null');
        return null;
      }
      return response as Map<String, dynamic>;
    } catch (e, stackTrace) {
      print('SupabaseRepository.changePassword: Error: $e');
      print('SupabaseRepository.changePassword: Stack trace: $stackTrace');
      rethrow;
    }
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

  Future<List<Map<String, dynamic>>> getCommandGroup() async {
    List<Map<String, dynamic>> list = [];
    try {
      final response = await _db.from('command_slots').select().order('slot_id');
      list = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error selecting command_slots: $e');
    }

    final existingIds = list.map((s) => s['slot_id'] as int).toSet();
    bool needUpdate = false;
    for (int i = 1; i <= 12; i++) {
      if (!existingIds.contains(i)) {
        needUpdate = true;
        try {
          String defaultRole = 'user';
          if (i == 1) {
            defaultRole = 'superadmin';
          } else if (i >= 2 && i <= 5) {
            defaultRole = 'admin';
          }

          await _db.from('command_slots').upsert({
            'slot_id': i,
            'role': defaultRole,
            'army_no': null,
            'username': 'slot$i',
            'password_hash': '123456',
          });
        } catch (e) {
          print('Error self-healing slot $i in database: $e');
          // If database upsert fails (e.g. due to RLS), pad locally
          String defaultRole = 'user';
          if (i == 1) {
            defaultRole = 'superadmin';
          } else if (i >= 2 && i <= 5) {
            defaultRole = 'admin';
          }
          list.add({
            'slot_id': i,
            'role': defaultRole,
            'army_no': null,
            'username': 'slot$i',
            'password_hash': '123456',
          });
        }
      }
    }

    if (needUpdate) {
      try {
        final newResponse = await _db.from('command_slots').select().order('slot_id');
        final newList = List<Map<String, dynamic>>.from(newResponse);
        if (newList.length >= list.length) {
          list = newList;
        }
      } catch (e) {
        // Keep the local list with padded items
      }
    }

    list.sort((a, b) => (a['slot_id'] as int).compareTo(b['slot_id'] as int));
    return list;
  }

  Future<void> assignSlot(
      int slotId, String armyNo, String username, String password, String role) async {
    await _db.from('command_slots').upsert({
      'slot_id': slotId,
      'army_no': armyNo.isEmpty ? null : armyNo,
      'username': username,
      'password_hash': password,
      'role': role,
    });
  }

  Future<void> clearSlot(int slotId) async {
    await _db.from('command_slots').update({
      'army_no': null,
      'username': 'slot$slotId',
      'password_hash': '123456',
    }).eq('slot_id', slotId);
  }
}
