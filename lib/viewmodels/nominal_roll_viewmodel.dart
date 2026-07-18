import 'package:flutter/foundation.dart';

/// ViewModel for the Nominal Roll tab.
/// Manages roll search query and all filter selections.
/// Extracted from _DashboardScreenState in dashboard_screen.dart.
class NominalRollViewModel extends ChangeNotifier {
  String _rollSearchQuery = '';
  String _selectedDivision = 'All';
  String _selectedBattery = 'All';
  String _selectedRankCategory = 'All';
  String _selectedTrade = 'All';

  // ── Getters ─────────────────────────────────────────────────────────────

  String get rollSearchQuery => _rollSearchQuery;
  String get selectedDivision => _selectedDivision;
  String get selectedBattery => _selectedBattery;
  String get selectedRankCategory => _selectedRankCategory;
  String get selectedTrade => _selectedTrade;

  // ── Setters ──────────────────────────────────────────────────────────────

  void setRollSearchQuery(String query) {
    _rollSearchQuery = query;
    notifyListeners();
  }

  void setSelectedDivision(String division) {
    _selectedDivision = division;
    notifyListeners();
  }

  void setSelectedBattery(String battery) {
    _selectedBattery = battery;
    notifyListeners();
  }

  void setSelectedRankCategory(String rankCategory) {
    _selectedRankCategory = rankCategory;
    notifyListeners();
  }

  void setSelectedTrade(String trade) {
    _selectedTrade = trade;
    notifyListeners();
  }

  void resetFilters() {
    _rollSearchQuery = '';
    _selectedDivision = 'All';
    _selectedBattery = 'All';
    _selectedRankCategory = 'All';
    _selectedTrade = 'All';
    notifyListeners();
  }
}
