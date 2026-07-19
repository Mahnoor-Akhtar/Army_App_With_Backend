import 'package:flutter/foundation.dart';
import '../services/mock_data.dart';
import '../services/supabase_repository.dart';

/// ViewModel for the main dashboard: controls tab index, parade-state
/// search, expanded sections, FAB state, roll edit/delete mode, and
/// dynamically loaded attribute lists.
/// Extracted from _DashboardScreenState in dashboard_screen.dart.
class DashboardViewModel extends ChangeNotifier {
  int _selectedTabIndex = 0;
  String _searchQuery = '';
  final Set<String> _expandedSections = {};
  bool _isFabMenuOpen = false;
  bool _isRollFabMenuOpen = false;
  bool _isRollEditMode = false;
  bool _isRollDeleteMode = false;

  // Dynamic attribute lists — initialized with minimal defaults, load from data source
  List<String> _tradesList = ['All'];
  List<String> _ranksList = ['All'];
  List<String> _batteriesList = ['All'];

  // ── Getters ─────────────────────────────────────────────────────────────

  int get selectedTabIndex => _selectedTabIndex;
  String get searchQuery => _searchQuery;
  Set<String> get expandedSections => _expandedSections;
  bool get isFabMenuOpen => _isFabMenuOpen;
  bool get isRollFabMenuOpen => _isRollFabMenuOpen;
  bool get isRollEditMode => _isRollEditMode;
  bool get isRollDeleteMode => _isRollDeleteMode;
  List<String> get tradesList => _tradesList;
  List<String> get ranksList => _ranksList;
  List<String> get batteriesList => _batteriesList;

  bool get canAccessEditTab {
    final role = MockDataManager().role;
    return role == 'Administrator' || role == 'Data Entry';
  }

  bool get canAccessFABs => MockDataManager().role != null;

  // ── Initialisation ───────────────────────────────────────────────────────

  DashboardViewModel() {
    loadDynamicAttributes();
  }

  Future<void> loadDynamicAttributes() async {
    try {
      final repo = SupabaseRepository();
      final trades = await repo.getSystemAttributeItems('trades');
      final ranks = await repo.getSystemAttributeItems('ranks');
      final batteries = await repo.getSystemAttributeItems('batteries');
      
      if (!trades.contains('All')) trades.insert(0, 'All');
      if (!ranks.contains('All')) ranks.insert(0, 'All');
      if (!batteries.contains('All')) batteries.insert(0, 'All');

      _tradesList = trades.isEmpty ? await MockDataManager().getTrades() : trades;
      _ranksList = ranks.isEmpty ? await MockDataManager().getRanks() : ranks;
      _batteriesList = batteries.isEmpty ? await MockDataManager().getBatteries() : batteries;
    } catch (e) {
      _tradesList = await MockDataManager().getTrades();
      _ranksList = await MockDataManager().getRanks();
      _batteriesList = await MockDataManager().getBatteries();
    }
    notifyListeners();
  }

  // ── Setters / Actions ────────────────────────────────────────────────────

  void setSelectedTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleSection(String sectionName) {
    if (_expandedSections.contains(sectionName)) {
      _expandedSections.remove(sectionName);
    } else {
      _expandedSections.add(sectionName);
    }
    notifyListeners();
  }

  bool isSectionExpanded(String sectionName) =>
      _expandedSections.contains(sectionName);

  void setFabMenuOpen(bool open) {
    _isFabMenuOpen = open;
    notifyListeners();
  }

  void setRollFabMenuOpen(bool open) {
    _isRollFabMenuOpen = open;
    notifyListeners();
  }

  void setRollEditMode(bool enabled) {
    _isRollEditMode = enabled;
    if (enabled) _isRollDeleteMode = false;
    notifyListeners();
  }

  void setRollDeleteMode(bool enabled) {
    _isRollDeleteMode = enabled;
    if (enabled) _isRollEditMode = false;
    notifyListeners();
  }

  void refreshAttributes() {
    loadDynamicAttributes();
  }
}
