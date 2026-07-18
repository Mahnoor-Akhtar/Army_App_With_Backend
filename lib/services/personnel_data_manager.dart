import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'personnel_data.dart';
import 'supabase_repository.dart';
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
    String? currentSub, 
    String? currentSubSub
  ) {
    // Don't generate dummy history; just return current status (history will come from database later
    final status = PersonStatus(
      category: currentCategory,
      subcategory: currentSub,
      subSubcategory: currentSubSub,
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
        status.subcategory, 
        status.subSubcategory
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

  void updateStatus(String armyNo, PersonStatus newStatus) {
    final oldStatus = _statuses[armyNo];
    if (oldStatus != null) {
      final finalOldStatus = PersonStatus(
        category: oldStatus.category,
        subcategory: oldStatus.subcategory,
        subSubcategory: oldStatus.subSubcategory,
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
  }

  List<PersonStatus> getHistory(String armyNo) {
    if (!_history.containsKey(armyNo) || _history[armyNo]!.isEmpty) {
      final current = getStatus(armyNo);
      _history[armyNo] = _generateThreeMonthHistory(
        armyNo, 
        current.category, 
        current.subcategory, 
        current.subSubcategory
      );
      saveToPrefs();
    }
    return _history[armyNo]!;
  }

  List<Map<String, String>> getPeopleInNode({
    required String category,
    String? subcategory,
    String? subSubcategory,
  }) {
    return nominalRollList.where((person) {
      final status = getStatus(person['armyNo'] ?? '');
      if (status.category != category) return false;
      if (subcategory != null && status.subcategory != subcategory) return false;
      if (subSubcategory != null && status.subSubcategory != subSubcategory) return false;
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

  int getCountForSubSubcategory(String categoryName, String subcategoryName, String subSubcategoryName) {
    return nominalRollList.where((p) {
      final status = getStatus(p['armyNo'] ?? '');
      return status.category == categoryName &&
             status.subcategory == subcategoryName &&
             status.subSubcategory == subSubcategoryName;
    }).length;
  }

  void addMainCategory(String name) {
    if (!categoryHierarchy.containsKey(name)) {
      categoryHierarchy[name] = null;
    }
  }

  void addSubcategory(String category, String subcategory) {
    if (!categoryHierarchy.containsKey(category)) return;
    
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
        saveToPrefs();
      }
    }
  }

  void addSubSubcategory(String category, String subcategory, String subSubcategory) {
    if (!categoryHierarchy.containsKey(category)) return;
    
    final current = categoryHierarchy[category];
    if (current == null || current is List) {
      final List<String> oldSubs = current == null ? [] : List<String>.from(current as List);
      final Map<String, List<String>> newMap = {};
      for (var sub in oldSubs) {
        newMap[sub] = [];
      }
      if (!newMap.containsKey(subcategory)) {
        newMap[subcategory] = [subSubcategory];
      } else {
        newMap[subcategory]!.add(subSubcategory);
      }
      categoryHierarchy[category] = newMap;
    } else if (current is Map) {
      final map = Map<String, dynamic>.from(current);
      if (!map.containsKey(subcategory)) {
        map[subcategory] = [subSubcategory];
      } else {
        final List<String> list = List<String>.from(map[subcategory] as List);
        if (!list.contains(subSubcategory)) {
          list.add(subSubcategory);
          map[subcategory] = list;
        }
      }
      categoryHierarchy[category] = map;
      saveToPrefs();
    }
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
  }

  void deleteCategory(String name) {
    if (!categoryHierarchy.containsKey(name)) return;

    categoryHierarchy.remove(name);

    for (var key in _statuses.keys) {
      final status = _statuses[key]!;
      if (status.category == name) {
        status.category = 'Present';
        status.subcategory = null;
        status.subSubcategory = null;
      }
    }
    saveToPrefs();
  }

  void renameSubcategory(String category, String oldSub, String newSub) {
    if (oldSub == newSub || !categoryHierarchy.containsKey(category)) return;

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
  }

  void deleteSubcategory(String category, String subcategory) {
    if (!categoryHierarchy.containsKey(category)) return;

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
        status.subSubcategory = null;
      }
    }
  }

  void renameSubSubcategory(String category, String subcategory, String oldSubSub, String newSubSub) {
    if (oldSubSub == newSubSub || !categoryHierarchy.containsKey(category)) return;

    final current = categoryHierarchy[category];
    if (current is Map) {
      final map = Map<String, dynamic>.from(current);
      if (map.containsKey(subcategory)) {
        final List<String> list = List<String>.from(map[subcategory] as List);
        final idx = list.indexOf(oldSubSub);
        if (idx != -1) {
          list[idx] = newSubSub;
          map[subcategory] = list;
          categoryHierarchy[category] = map;
        }
      }
    }

    for (var key in _statuses.keys) {
      final status = _statuses[key]!;
      if (status.category == category &&
          status.subcategory == subcategory &&
          status.subSubcategory == oldSubSub) {
        status.subSubcategory = newSubSub;
      }
    }
  }

  void deleteSubSubcategory(String category, String subcategory, String subSubName) {
    if (!categoryHierarchy.containsKey(category)) return;

    final current = categoryHierarchy[category];
    if (current is Map) {
      final map = Map<String, dynamic>.from(current);
      if (map.containsKey(subcategory)) {
        final List<String> list = List<String>.from(map[subcategory] as List);
        list.remove(subSubName);
        map[subcategory] = list;
        categoryHierarchy[category] = map;
      }
    }

    for (var key in _statuses.keys) {
      final status = _statuses[key]!;
      if (status.category == category &&
          status.subcategory == subcategory &&
          status.subSubcategory == subSubName) {
        status.subSubcategory = null;
      }
    }
  }

  void addPerson(Map<String, String> person) {
    final armyNo = person['armyNo'] ?? '';
    if (nominalRollList.any((p) => p['armyNo'] == armyNo)) return;
    nominalRollList.add(person);
    saveToPrefs();
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
