import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'personnel_data.dart';
import 'supabase_repository.dart';
import 'mock_data.dart';
import '../models/person_status.dart';
import '../models/group_model.dart';
export '../models/person_status.dart'; // Re-export so existing imports of personnel_data_manager.dart still resolve PersonStatus
export '../models/group_model.dart'; // Re-export GroupModel


class PersonnelDataManager extends ChangeNotifier {
  static final PersonnelDataManager _instance = PersonnelDataManager._internal();

  factory PersonnelDataManager() {
    return _instance;
  }

  PersonnelDataManager._internal();

  late SharedPreferences _prefs;
  final Map<String, PersonStatus> _statuses = {};
  final Map<String, List<PersonStatus>> _history = {};
  bool _isInitialized = false;

  void init(SharedPreferences prefs) {
    if (_isInitialized) return;
    _prefs = prefs;

    // One-time clear of old data to fix duplicates
    if (!_prefs.containsKey('data_v2_cleared')) {
      _prefs.remove('categoryHierarchy');
      _prefs.remove('personnelStatuses');
      _prefs.remove('personnelHistory');
      _prefs.setBool('data_v2_cleared', true);
    }

    _loadFromPrefs();
    _isInitialized = true;
  }

  void _loadCategoryHierarchyFromSupabase() {
    try {
      final repo = SupabaseRepository();
      repo.getStatusHierarchy().then((hierarchy) {
        categoryHierarchy = hierarchy;
        saveToPrefs(); // Save to SharedPreferences for future offline use
        notifyListeners();
      }).catchError((e) {
        // Fallback to default if Supabase fails
        _useDefaultCategories();
      });
    } catch (e) {
      // Fallback to default if Supabase fails
      _useDefaultCategories();
    }
  }

  void _loadFromPrefs() {
    // 1. load categoryHierarchy (with deduplication and clearing old data)
    final catStr = _prefs.getString('categoryHierarchy');
    bool needsReset = false;
    if (catStr != null) {
      try {
        final tempHierarchy = Map<String, dynamic>.from(jsonDecode(catStr));
        // Deduplicate category keys
        final uniqueKeys = <String>{};
        final cleanHierarchy = <String, dynamic>{};
        tempHierarchy.forEach((key, value) {
          if (!uniqueKeys.contains(key)) {
            uniqueKeys.add(key);
            cleanHierarchy[key] = value;
          } else {
            needsReset = true;
          }
        });
        if (needsReset) {
          categoryHierarchy = {};
        } else {
          categoryHierarchy = cleanHierarchy;
        }
      } catch (e) {
        needsReset = true;
      }
    } else {
      needsReset = true;
    }
    if (needsReset) {
      _useDefaultCategories();
    }

    // Try to load latest hierarchy from Supabase (async, don't await)
    _loadCategoryHierarchyFromSupabase();

    // 2. load nominalRollList
    final rollStr = _prefs.getString('nominalRollList');
    if (rollStr != null) {
      try {
        final decoded = jsonDecode(rollStr) as List;
        nominalRollList.clear();
        nominalRollList.addAll(decoded.map((p) => Map<String, String>.from(p as Map)));
      } catch (e) {
        // use default from file
      }
    }

    // 3. load _statuses and _history
    final statusesStr = _prefs.getString('personnelStatuses');
    final historyStr = _prefs.getString('personnelHistory');
    
    if (statusesStr != null) {
      try {
        final decoded = jsonDecode(statusesStr) as Map;
        _statuses.clear();
        decoded.forEach((key, value) {
          _statuses[key as String] = PersonStatus.fromJson(Map<String, dynamic>.from(value as Map));
        });
      } catch (e) {
        _initializeStatuses();
      }
    } else {
      _initializeStatuses();
    }

    if (historyStr != null) {
      try {
        final decoded = jsonDecode(historyStr) as Map;
        _history.clear();
        decoded.forEach((key, value) {
          final list = value as List;
          _history[key as String] = list.map((item) => PersonStatus.fromJson(Map<String, dynamic>.from(item as Map))).toList();
        });
      } catch (e) {
        _initializeHistory();
      }
    } else {
      _initializeHistory();
    }
    _loadCustomGroups();
    
    // Fetch latest personnel from database
    _loadPersonnelFromSupabase();
  }

  Future<void> _loadPersonnelFromSupabase() async {
    try {
      final repo = SupabaseRepository();
      final personnelList = await repo.getAllPersonnel();
      
      if (personnelList.isNotEmpty) {
        nominalRollList.clear();
        for (var p in personnelList) {
          nominalRollList.add({
            'armyNo': p.armyNo,
            'rank': p.rank,
            'name': p.name,
            'trade': p.trade,
            'category': p.category,
            'cl': p.cl,
            'battery': p.battery,
            'avatar': p.profilePhoto ?? '',
            'phone': p.phoneNumber ?? '',
            'city': p.city ?? '',
            'remarks': p.remarks ?? '',
          });
        }
        
        // Fetch current statuses AND full history from database for each person
        final statusList = await repo.getCurrentPersonnelStatus();
        final statusMap = { for (var s in statusList) s['army_no']: s };

        for (var p in personnelList) {
          final s = statusMap[p.armyNo];
          if (s != null) {
            // Only use status history fields (personnel table no longer has status fields)
            final category = s['current_category'] ?? 'Present';
            final subcategory = s['current_subcategory'];
            final startDate = s['start_date'] != null ? DateTime.parse(s['start_date']) : DateTime.now();
            
            DateTime? endDate;
            if (s['end_date'] != null) {
              endDate = DateTime.tryParse(s['end_date'].toString());
            } else if (s['status_remarks'] != null) {
              final remarksStr = s['status_remarks'].toString();
              final match = RegExp(r'Planned return: (\d{4}-\d{2}-\d{2})').firstMatch(remarksStr);
              if (match != null) {
                endDate = DateTime.tryParse(match.group(1)!);
              }
            }
            
            _statuses[p.armyNo] = PersonStatus(
              category: category,
              subcategory: subcategory,
              destination: s['destination'],
              startDate: startDate,
              endDate: endDate,
            );
          } else if (!_statuses.containsKey(p.armyNo)) {
            _statuses[p.armyNo] = PersonStatus(
              category: 'Present',
              startDate: DateTime.now(),
              endDate: null,
            );
          }

          // Load status history from database for this person
          try {
            final historyList = await repo.getStatusHistory(p.armyNo);
            _history[p.armyNo] = historyList.map((h) => PersonStatus(
              category: h.category,
              subcategory: h.subcategory,
              destination: h.destination,
              startDate: h.startDate,
              endDate: h.endDate,
            )).toList();
          } catch (e) {
            if (kDebugMode) {
              print('Error loading status history for ${p.armyNo}: $e');
            }
          }
        }
        saveToPrefs();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading personnel from database: $e');
      }
      // Keep local data on failure
    }
  }

  void saveToPrefs() {
    _prefs.setString('categoryHierarchy', jsonEncode(categoryHierarchy));
    _prefs.setString('nominalRollList', jsonEncode(nominalRollList));
    
    final Map<String, dynamic> jsonStatuses = {};
    _statuses.forEach((key, value) {
      jsonStatuses[key] = value.toJson();
    });
    _prefs.setString('personnelStatuses', jsonEncode(jsonStatuses));

    final Map<String, dynamic> jsonHistory = {};
    _history.forEach((key, value) {
      jsonHistory[key] = value.map((status) => status.toJson()).toList();
    });
    _prefs.setString('personnelHistory', jsonEncode(jsonHistory));
  }

  void _useDefaultCategories() {
    categoryHierarchy = {};
    saveToPrefs(); // Ensure old data is cleared from SharedPreferences
  }

  Map<String, dynamic> categoryHierarchy = {};

  void _initializeStatuses() {
    for (var person in nominalRollList) {
      final armyNo = person['armyNo'] ?? '';
      // Initialize with just Present/Duty (no dummy history or history comes from database
      final newStatus = PersonStatus(
        category: 'Present',
        subcategory: 'Duty',
        startDate: DateTime.now(),
        endDate: null,
      );
      _statuses[armyNo] = newStatus;
      _history[armyNo] = [newStatus];
    }
  }

  List<PersonStatus> _generateThreeMonthHistory(
    String armyNo, 
    String currentCategory, 
    String? currentSub
  ) {
    // Don't generate dummy history; just return current status (history will come from database later
    final status = PersonStatus(
      category: currentCategory,
      subcategory: currentSub,
      
      startDate: DateTime.now(),
      endDate: null,
    );
    return [status];
  }

  void _initializeHistory() {
    _history.clear();
    _statuses.forEach((armyNo, status) {
      _history[armyNo] = _generateThreeMonthHistory(
        armyNo, 
        status.category, 
        status.subcategory
      );
    });
  }

  String _getInitialCategory(String armyNo) {
    final cleanNo = armyNo.replaceAll(RegExp(r'\D'), '');
    if (cleanNo.isEmpty) return 'Present';
    final id = int.tryParse(cleanNo) ?? 0;

    final statusList = [
      'Present', 'Leave', 'Aval', 'Att', 'Courses', 'OSL/Pris', 
      'Sta Gds', 'Unit Gds', 'CMH/Sick', 'Regt Emp', 'Trg', 'Sports', 
      'Aslt Course', 'DIDO', 'Working', 'Prot', 'Ex/Cl', 'U/D'
    ];
    
    final weights = [83, 85, 83, 33, 47, 47, 33, 48, 5, 30, 22, 22, 3, 22, 22, 22, 33, 33];
    final sum = weights.reduce((a, b) => a + b);
    
    final val = id % sum;
    int currentSum = 0;
    for (int i = 0; i < weights.length; i++) {
      currentSum += weights[i];
      if (val < currentSum) {
        return statusList[i];
      }
    }
    return 'Present';
  }

  PersonStatus getStatus(String armyNo) {
    if (!_statuses.containsKey(armyNo)) {
      _statuses[armyNo] = PersonStatus(
        category: 'Present',
        startDate: DateTime.now(),
        endDate: null,
      );
      saveToPrefs();
    }
    return _statuses[armyNo]!;
  }

  Future<void> updateStatus(String armyNo, PersonStatus newStatus) async {
    final oldStatus = _statuses[armyNo];
    if (oldStatus != null) {
      final finalOldStatus = PersonStatus(
        category: oldStatus.category,
        subcategory: oldStatus.subcategory,
        startDate: oldStatus.startDate,
        endDate: newStatus.startDate,
      );

      if (!_history.containsKey(armyNo)) {
        _history[armyNo] = [finalOldStatus];
      } else {
        _history[armyNo]!.removeWhere((s) => s.endDate == null);
        _history[armyNo]!.add(finalOldStatus);
      }
    }

    _statuses[armyNo] = newStatus;

    if (!_history.containsKey(armyNo)) {
      _history[armyNo] = [newStatus];
    } else {
      _history[armyNo]!.removeWhere((s) => s.endDate == null);
      _history[armyNo]!.add(newStatus);
    }
    saveToPrefs();

    // Sync to database
    try {
      if (kDebugMode) {
        print('Calling updatePersonnelStatus for $armyNo');
        print('  category: ${newStatus.category}');
        print('  subcategory: ${newStatus.subcategory}');
        print('  startDate: ${newStatus.startDate}');
      }
      await SupabaseRepository().updatePersonnelStatus(
        armyNo: armyNo,
        category: newStatus.category,
        subcategory: newStatus.subcategory,
        destination: newStatus.destination,
        startDate: newStatus.startDate,
        endDate: newStatus.endDate,
        createdBy: MockDataManager().username,
      );
      if (kDebugMode) {
        print('Successfully updated status in database!');
      }
      
      // Fetch latest data from database
      await _loadPersonnelFromSupabase();

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error syncing personnel status to database: $e');
        print('Stack trace: $stackTrace');
      }
    }
  }

  Future<List<PersonStatus>> getHistory(String armyNo) async {
    if (!_history.containsKey(armyNo) || _history[armyNo]!.isEmpty) {
      // Try to load from database first
      try {
        final repo = SupabaseRepository();
        final historyList = await repo.getStatusHistory(armyNo);
        if (historyList.isNotEmpty) {
          _history[armyNo] = historyList.map((h) => PersonStatus(
            category: h.category,
            subcategory: h.subcategory,
            destination: h.destination,
            startDate: h.startDate,
            endDate: h.endDate,
          )).toList();
        } else {
          // If no history in database, use current status
          final current = getStatus(armyNo);
          _history[armyNo] = [current];
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading history from database: $e');
        }
        // Fallback to current status
        final current = getStatus(armyNo);
        _history[armyNo] = [current];
      }
      saveToPrefs();
    }
    return _history[armyNo]!;
  }

  List<Map<String, String>> getPeopleInNode({
    required String category,
    String? subcategory,
  }) {
    return nominalRollList.where((person) {
      final status = getStatus(person['armyNo'] ?? '');
      if (status.category != category) return false;
      if (subcategory != null && status.subcategory != subcategory) return false;
      return true;
    }).toList();
  }

  int getCountForCategory(String categoryName) {
    return nominalRollList.where((p) => getStatus(p['armyNo'] ?? '').category == categoryName).length;
  }

  int getCountForSubcategory(String categoryName, String subcategoryName) {
    return nominalRollList.where((p) {
      final status = getStatus(p['armyNo'] ?? '');
      return status.category == categoryName && status.subcategory == subcategoryName;
    }).length;
  }



  void addMainCategory(String name) {
    if (!categoryHierarchy.containsKey(name)) {
      categoryHierarchy[name] = null;
      saveToPrefs();
      SupabaseRepository().syncStatusHierarchy(categoryHierarchy);
    }
  }

  /// Adds a subcategory (or sub-subcategory when [subSubcategory] is provided).
  ///
  /// - 2-arg form: adds [subcategory] under [category].
  /// - 3-arg form: adds [subSubcategory] under [category] → [subcategory].
  void addSubcategory(String category, String subcategory,
      [String? subSubcategory]) {
    if (!categoryHierarchy.containsKey(category)) return;

    if (subSubcategory != null) {
      // 3-level: add sub-subcategory under category -> subcategory
      final current = categoryHierarchy[category];
      if (current is Map) {
        final map = Map<String, dynamic>.from(current);
        final subList = map[subcategory];
        if (subList is List) {
          final list = List<String>.from(subList);
          if (!list.contains(subSubcategory)) {
            list.add(subSubcategory);
            map[subcategory] = list;
            categoryHierarchy[category] = map;
          }
        } else {
          map[subcategory] = [subSubcategory];
          categoryHierarchy[category] = map;
        }
      } else {
        // Convert to map structure
        categoryHierarchy[category] = {
          subcategory: [subSubcategory],
        };
      }
      saveToPrefs();
      SupabaseRepository().syncStatusHierarchy(categoryHierarchy);
      return;
    }

    final current = categoryHierarchy[category];
    if (current == null) {
      categoryHierarchy[category] = [subcategory];
    } else if (current is List) {
      final list = List<String>.from(current);
      if (!list.contains(subcategory)) {
        list.add(subcategory);
        categoryHierarchy[category] = list;
      }
    } else if (current is Map) {
      final map = Map<String, dynamic>.from(current);
      if (!map.containsKey(subcategory)) {
        map[subcategory] = [];
        categoryHierarchy[category] = map;
      }
    }
    saveToPrefs();
    SupabaseRepository().syncStatusHierarchy(categoryHierarchy);
  }



  void renameCategory(String oldName, String newName) {
    if (oldName == newName || !categoryHierarchy.containsKey(oldName)) return;
    
    final data = categoryHierarchy.remove(oldName);
    categoryHierarchy[newName] = data;

    for (var key in _statuses.keys) {
      final status = _statuses[key]!;
      if (status.category == oldName) {
        status.category = newName;
      }
    }
    saveToPrefs();
    SupabaseRepository().syncStatusHierarchy(categoryHierarchy);
  }

  void deleteCategory(String name) {
    if (!categoryHierarchy.containsKey(name)) return;

    categoryHierarchy.remove(name);

    for (var key in _statuses.keys) {
      final status = _statuses[key]!;
      if (status.category == name) {
        status.category = 'Present';
        status.subcategory = null;
      }
    }
    saveToPrefs();
  }

  /// Renames a subcategory or sub-subcategory.
  ///
  /// - 3-arg form `(category, oldSub, newSub)`: renames a subcategory.
  /// - 4-arg form `(category, parentSub, oldSubSub, newSubSub)`: renames a
  ///   sub-subcategory inside [parentSub].
  void renameSubcategory(String category, String oldSubOrParent,
      String newSubOrOldSubSub,
      [String? newSubSub]) {
    if (!categoryHierarchy.containsKey(category)) return;

    if (newSubSub != null) {
      // 4-arg: rename sub-subcategory: oldSubOrParent=parentSub,
      //        newSubOrOldSubSub=oldSubSub, newSubSub=newSubSub
      final parentSub = oldSubOrParent;
      final oldSubSub = newSubOrOldSubSub;
      if (oldSubSub == newSubSub) return;
      final current = categoryHierarchy[category];
      if (current is Map) {
        final map = Map<String, dynamic>.from(current);
        final subList = map[parentSub];
        if (subList is List) {
          final list = List<String>.from(subList);
          final idx = list.indexOf(oldSubSub);
          if (idx != -1) {
            list[idx] = newSubSub;
            map[parentSub] = list;
            categoryHierarchy[category] = map;
          }
        }
      }
      saveToPrefs();
      SupabaseRepository().syncStatusHierarchy(categoryHierarchy);
      return;
    }

    // 3-arg: rename subcategory
    final oldSub = oldSubOrParent;
    final newSub = newSubOrOldSubSub;
    if (oldSub == newSub) return;

    final current = categoryHierarchy[category];
    if (current is List) {
      final list = List<String>.from(current);
      final idx = list.indexOf(oldSub);
      if (idx != -1) {
        list[idx] = newSub;
        categoryHierarchy[category] = list;
      }
    } else if (current is Map) {
      final map = Map<String, dynamic>.from(current);
      if (map.containsKey(oldSub)) {
        final val = map.remove(oldSub);
        map[newSub] = val;
        categoryHierarchy[category] = map;
      }
    }

    for (var key in _statuses.keys) {
      final status = _statuses[key]!;
      if (status.category == category && status.subcategory == oldSub) {
        status.subcategory = newSub;
      }
    }
    saveToPrefs();
    SupabaseRepository().syncStatusHierarchy(categoryHierarchy);
  }

  /// Deletes a subcategory or sub-subcategory.
  ///
  /// - 2-arg form `(category, subcategory)`: deletes a subcategory.
  /// - 3-arg form `(category, parentSub, subSubcategory)`: deletes a
  ///   sub-subcategory inside [parentSub].
  void deleteSubcategory(String category, String subOrParent,
      [String? subSubcategory]) {
    if (!categoryHierarchy.containsKey(category)) return;

    if (subSubcategory != null) {
      // 3-arg: delete sub-subcategory
      final parentSub = subOrParent;
      final current = categoryHierarchy[category];
      if (current is Map) {
        final map = Map<String, dynamic>.from(current);
        final subList = map[parentSub];
        if (subList is List) {
          final list = List<String>.from(subList);
          list.remove(subSubcategory);
          map[parentSub] = list.isEmpty ? null : list;
          categoryHierarchy[category] = map;
        }
      }
      saveToPrefs();
      SupabaseRepository().syncStatusHierarchy(categoryHierarchy);
      return;
    }

    // 2-arg: delete subcategory
    final subcategory = subOrParent;
    final current = categoryHierarchy[category];
    if (current is List) {
      final list = List<String>.from(current);
      list.remove(subcategory);
      categoryHierarchy[category] = list.isEmpty ? null : list;
    } else if (current is Map) {
      final map = Map<String, dynamic>.from(current);
      map.remove(subcategory);
      categoryHierarchy[category] = map.isEmpty ? null : map;
    }

    for (var key in _statuses.keys) {
      final status = _statuses[key]!;
      if (status.category == category && status.subcategory == subcategory) {
        status.subcategory = null;
      }
    }
    saveToPrefs();
    SupabaseRepository().syncStatusHierarchy(categoryHierarchy);
  }



  void addPerson(Map<String, String> person) {
    final armyNo = person['armyNo'] ?? '';
    if (nominalRollList.any((p) => p['armyNo'] == armyNo)) return;
    nominalRollList.add(person);
    saveToPrefs();

    // Sync to database
    SupabaseRepository().addPersonnel({
      'army_no': person['armyNo'],
      'rank': person['rank'],
      'name': person['name'],
      'trade': person['trade'],
      'category': person['category'],
      'cl': person['cl'],
      'battery': person['battery'],
      'phone_number': person['phone'],
      'city': person['city'],
      'remarks': person['remarks'],
      'fighting_status': person['isFighting'] == 'true' ? 'Fighting' : 'Non-Fighting',
      'profile_photo': person['avatar'],
    }).catchError((e) {
      if (kDebugMode) {
        print('Error adding personnel to database: $e');
      }
    });
  }

  void editPerson(String oldArmyNo, Map<String, String> updatedPerson) {
    final idx = nominalRollList.indexWhere((p) => p['armyNo'] == oldArmyNo);
    if (idx != -1) {
      nominalRollList[idx] = updatedPerson;
      final newArmyNo = updatedPerson['armyNo'] ?? '';

      if (oldArmyNo != newArmyNo && newArmyNo.isNotEmpty) {
        final status = _statuses.remove(oldArmyNo);
        if (status != null) {
          _statuses[newArmyNo] = status;
        }
        final historyList = _history.remove(oldArmyNo);
        if (historyList != null) {
          _history[newArmyNo] = historyList;
        }
      }

      saveToPrefs();

      // Sync to database
      SupabaseRepository().updatePersonnel(oldArmyNo, {
        'army_no': updatedPerson['armyNo'],
        'rank': updatedPerson['rank'],
        'name': updatedPerson['name'],
        'trade': updatedPerson['trade'],
        'category': updatedPerson['category'],
        'cl': updatedPerson['cl'],
        'battery': updatedPerson['battery'],
        'phone_number': updatedPerson['phone'],
        'city': updatedPerson['city'],
        'remarks': updatedPerson['remarks'],
        'fighting_status': updatedPerson['isFighting'] == 'true' ? 'Fighting' : 'Non-Fighting',
        'profile_photo': updatedPerson['avatar'],
      }).catchError((e) {
        if (kDebugMode) {
          print('Error updating personnel in database: $e');
        }
      });
    }
  }

  void removePerson(String armyNo) {
    nominalRollList.removeWhere((p) => p['armyNo'] == armyNo);
    _statuses.remove(armyNo);
    _history.remove(armyNo);
    saveToPrefs();
  }

  // --- Dynamic Custom Groups Management ---

  final List<GroupModel> _customGroups = [];

  List<GroupModel> get customGroups => List.unmodifiable(_customGroups);

  void _loadCustomGroups() {
    final str = _prefs.getString('customGroups');
    if (str != null) {
      try {
        final List decoded = jsonDecode(str);
        _customGroups.clear();
        _customGroups.addAll(decoded.map((g) => GroupModel.fromJson(Map<String, dynamic>.from(g as Map))));
      } catch (e) {
        _useDefaultCustomGroups();
      }
    } else {
      _useDefaultCustomGroups();
    }
  }

  void _useDefaultCustomGroups() {
    _customGroups.clear();
    _saveCustomGroups();
  }

  void _saveCustomGroups() {
    _prefs.setString('customGroups', jsonEncode(_customGroups.map((g) => g.toJson()).toList()));
  }

  void addCustomGroup(GroupModel group) {
    _customGroups.add(group);
    _saveCustomGroups();
  }

  void updateCustomGroup(GroupModel updatedGroup) {
    final index = _customGroups.indexWhere((g) => g.id == updatedGroup.id);
    if (index != -1) {
      _customGroups[index] = updatedGroup;
      _saveCustomGroups();
    }
  }

  void deleteCustomGroup(String id) {
    _customGroups.removeWhere((g) => g.id == id);
    _saveCustomGroups();
  }
}
