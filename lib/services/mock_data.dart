import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MockDataManager {
  static final MockDataManager _instance = MockDataManager._internal();

  factory MockDataManager() {
    return _instance;
  }

  MockDataManager._internal();

  String? _username;
  String? _role;
  String? _adminArmyNo;
  bool _isLoggedIn = false;

  void login(String username, String role, {String? adminArmyNo}) {
    _username = username;
    _role = role;
    _adminArmyNo = adminArmyNo;
    _isLoggedIn = true;
  }

  void logout() {
    _username = null;
    _role = null;
    _adminArmyNo = null;
    _isLoggedIn = false;
  }

  String? get username => _username;
  String? get role => _role;
  String? get adminArmyNo => _adminArmyNo;
  bool get isLoggedIn => _isLoggedIn;

  Future<List<Map<String, dynamic>>> getCommandGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('commandGroup_v2');
    if (str != null) {
      try {
        final List decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        // Fallback
      }
    }
    
    // Initialize default 12 slots
    final List<Map<String, dynamic>> defaultGroup = List.generate(12, (index) {
      final i = index + 1;
      String defaultRole = 'user';
      if (i == 1) {
        defaultRole = 'superadmin';
      } else if (i >= 2 && i <= 5) {
        defaultRole = 'admin';
      }
      return {
        'slotId': i,
        'role': defaultRole,
        'armyNo': null,
        'username': '',
        'password': '',
      };
    });
    
    await saveCommandGroup(defaultGroup);
    return defaultGroup;
  }

  Future<void> saveCommandGroup(List<Map<String, dynamic>> group) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('commandGroup_v2', jsonEncode(group));
  }

  Future<void> assignSlot(int slotId, String armyNo, String username, String password, String role) async {
    final group = await getCommandGroup();
    bool found = false;
    for (var slot in group) {
      if (slot['slotId'] == slotId) {
        slot['armyNo'] = armyNo;
        slot['username'] = username.trim();
        slot['password'] = password;
        slot['role'] = role;
        found = true;
        break;
      }
    }
    if (!found) {
      group.add({
        'slotId': slotId,
        'role': role,
        'armyNo': armyNo,
        'username': username.trim(),
        'password': password,
      });
    }
    await saveCommandGroup(group);
  }

  Future<void> clearSlot(int slotId) async {
    final group = await getCommandGroup();
    for (var slot in group) {
      if (slot['slotId'] == slotId) {
        slot['armyNo'] = null;
        slot['username'] = "";
        slot['password'] = "";
        break;
      }
    }
    await saveCommandGroup(group);
  }

  Future<void> updateCredentials(String armyNo, String username, String password) async {
    final group = await getCommandGroup();
    for (var slot in group) {
      if (slot['armyNo'] == armyNo) {
        slot['username'] = username.trim();
        slot['password'] = password;
        break;
      }
    }
    await saveCommandGroup(group);
  }

  // Deprecated backward compatibility methods
  Future<Map<String, dynamic>> getAdminAccounts() async {
    final group = await getCommandGroup();
    final Map<String, dynamic> result = {};
    for (var slot in group) {
      if (slot['armyNo'] != null) {
        result[slot['armyNo'] as String] = {
          'username': slot['username'],
          'password': slot['password'],
        };
      }
    }
    return result;
  }

  Future<List<String>> getAdminArmyNos() async {
    final group = await getCommandGroup();
    return group
        .where((s) => s['armyNo'] != null)
        .map((s) => s['armyNo'] as String)
        .toList();
  }

  Future<List<String>> getAdmins() async {
    final group = await getCommandGroup();
    return group
        .where((s) => s['armyNo'] != null)
        .map((s) => s['username'].toString().toLowerCase())
        .toList();
  }
  Future<void> changePassword(String currentUsername, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final usernameLower = currentUsername.toLowerCase();
    
    if (usernameLower == 'superadmin' || usernameLower == 'admin' || usernameLower == 'user') {
      await prefs.setString('system_${usernameLower}_password', newPassword);
      return;
    }
    
    final group = await getCommandGroup();
    for (var slot in group) {
      if (slot['username'].toString().toLowerCase() == usernameLower) {
        slot['password'] = newPassword;
        break;
      }
    }
    await saveCommandGroup(group);
  }

  // --- Dynamic Attributes Management ---

  Future<List<String>> getTrades() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('trades_list');
    if (str != null) {
      try {
        final list = List<String>.from(jsonDecode(str));
        if (list.length > 14) {
          return list;
        }
      } catch (_) {}
    }
    final defaultTrades = ['All'];
    await prefs.setString('trades_list', jsonEncode(defaultTrades));
    return defaultTrades;
  }

  Future<void> saveTrades(List<String> trades) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trades_list', jsonEncode(trades));
  }

  Future<List<String>> getRanks() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('ranks_list');
    if (str != null) {
      try {
        final list = List<String>.from(jsonDecode(str));
        if (list.length > 4) {
          return list;
        }
      } catch (_) {}
    }
    final defaultRanks = ['All'];
    await prefs.setString('ranks_list', jsonEncode(defaultRanks));
    return defaultRanks;
  }

  Future<void> saveRanks(List<String> ranks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ranks_list', jsonEncode(ranks));
  }

  Future<List<String>> getBatteries() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('batteries_list');
    if (str != null) {
      try {
        return List<String>.from(jsonDecode(str));
      } catch (_) {}
    }
    return ['All'];
  }

  Future<void> saveBatteries(List<String> batteries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('batteries_list', jsonEncode(batteries));
  }
}