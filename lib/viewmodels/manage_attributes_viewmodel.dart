import 'package:flutter/foundation.dart';
import '../services/mock_data.dart';
import '../services/supabase_repository.dart';

/// ViewModel for the Manage Attributes screen.
/// Manages trades, ranks, and batteries lists with full CRUD.
/// Extracted from _ManageAttributesScreenState in manage_attributes_screen.dart.
class ManageAttributesViewModel extends ChangeNotifier {
  List<String> trades = [];
  List<String> ranks = [];
  List<String> batteries = [];
  List<String> categories = [];
  bool isLoading = true;

  ManageAttributesViewModel() {
    loadAttributes();
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> loadAttributes() async {
    isLoading = true;
    notifyListeners();

    try {
      final repo = SupabaseRepository();
      trades = await repo.getSystemAttributeItems('trades');
      ranks = await repo.getSystemAttributeItems('ranks');
      batteries = await repo.getSystemAttributeItems('batteries');
      categories = await repo.getSystemAttributeItems('categories');

      if (!trades.contains('All')) trades.insert(0, 'All');
      if (!ranks.contains('All')) ranks.insert(0, 'All');
      if (!batteries.contains('All')) batteries.insert(0, 'All');
      if (!categories.contains('All')) categories.insert(0, 'All');
    } catch (e) {
      trades = await MockDataManager().getTrades();
      ranks = await MockDataManager().getRanks();
      batteries = await MockDataManager().getBatteries();
    }

    if (trades.isEmpty) trades = await MockDataManager().getTrades();
    if (ranks.isEmpty) ranks = await MockDataManager().getRanks();
    if (batteries.isEmpty) batteries = await MockDataManager().getBatteries();

    isLoading = false;
    notifyListeners();
  }

  // ── Save helpers ─────────────────────────────────────────────────────────

  Future<void> _saveTrades() async {
    await MockDataManager().saveTrades(trades);
    try { await SupabaseRepository().updateSystemAttributeItems('trades', trades); } catch (_) {}
  }

  Future<void> _saveRanks() async {
    await MockDataManager().saveRanks(ranks);
    try { await SupabaseRepository().updateSystemAttributeItems('ranks', ranks); } catch (_) {}
  }

  Future<void> _saveBatteries() async {
    await MockDataManager().saveBatteries(batteries);
    try { await SupabaseRepository().updateSystemAttributeItems('batteries', batteries); } catch (_) {}
  }

  Future<void> _saveCategories() async {
    // No MockDataManager method for categories yet, only save to Supabase
    try { await SupabaseRepository().updateSystemAttributeItems('categories', categories); } catch (_) {}
  }

  // ── Trade CRUD ───────────────────────────────────────────────────────────

  Future<void> addTrade(String value) async {
    trades.add(value);
    notifyListeners();
    await _saveTrades();
  }

  Future<void> editTrade(int index, String value) async {
    trades[index] = value;
    notifyListeners();
    await _saveTrades();
  }

  Future<void> deleteTrade(int index) async {
    trades.removeAt(index);
    notifyListeners();
    await _saveTrades();
  }

  // ── Rank CRUD ────────────────────────────────────────────────────────────

  Future<void> addRank({
    required String value,
    required String selectedType,
    String? selectedParent,
  }) async {
    final formattedVal = selectedType == 'Category' ? value : '  $value';

    if (selectedType == 'Category') {
      ranks.add(formattedVal);
    } else {
      if (selectedParent != null) {
        int insertIdx = ranks.indexOf(selectedParent);
        if (insertIdx != -1) {
          int i = insertIdx + 1;
          while (i < ranks.length && ranks[i].startsWith(' ')) {
            i++;
          }
          ranks.insert(i, formattedVal);
        } else {
          ranks.add(formattedVal);
        }
      } else {
        ranks.add(formattedVal);
      }
    }
    notifyListeners();
    await _saveRanks();
  }

  Future<void> editRank({
    required int index,
    required String value,
    required String selectedType,
    String? selectedParent,
  }) async {
    ranks.removeAt(index);

    final formattedVal = selectedType == 'Category' ? value : '  $value';

    if (selectedType == 'Category') {
      if (index < ranks.length) {
        ranks.insert(index, formattedVal);
      } else {
        ranks.add(formattedVal);
      }
    } else {
      if (selectedParent != null) {
        int insertIdx = ranks.indexOf(selectedParent);
        if (insertIdx != -1) {
          int i = insertIdx + 1;
          while (i < ranks.length && ranks[i].startsWith(' ')) {
            i++;
          }
          ranks.insert(i, formattedVal);
        } else {
          ranks.add(formattedVal);
        }
      } else {
        ranks.add(formattedVal);
      }
    }
    notifyListeners();
    await _saveRanks();
  }

  Future<void> deleteRank(int index) async {
    ranks.removeAt(index);
    notifyListeners();
    await _saveRanks();
  }

  // ── Battery CRUD ─────────────────────────────────────────────────────────

  Future<void> addBattery(String value) async {
    batteries.add(value);
    notifyListeners();
    await _saveBatteries();
  }

  Future<void> editBattery(int index, String value) async {
    batteries[index] = value;
    notifyListeners();
    await _saveBatteries();
  }

  Future<void> deleteBattery(int index) async {
    batteries.removeAt(index);
    notifyListeners();
    await _saveBatteries();
  }

  // ── Category CRUD ───────────────────────────────────────────────────────

  Future<void> addCategory(String value) async {
    categories.add(value);
    notifyListeners();
    await _saveCategories();
  }

  Future<void> editCategory(int index, String value) async {
    categories[index] = value;
    notifyListeners();
    await _saveCategories();
  }

  Future<void> deleteCategory(int index) async {
    categories.removeAt(index);
    notifyListeners();
    await _saveCategories();
  }
}
