import 'package:flutter/foundation.dart';

/// ViewModel for the Analysis tab.
/// Manages analysis mode selection and analysis filter state.
/// Extracted from _DashboardScreenState in dashboard_screen.dart.
class AnalysisViewModel extends ChangeNotifier {
  String _analysisMode = 'Rank'; // Default to Rank Analysis
  List<String> _analysisFilterBattery = ['All'];
  List<String> _analysisFilterTrade = ['All'];
  List<String> _analysisFilterRank = ['All'];

  // ── Getters ─────────────────────────────────────────────────────────────

  String get analysisMode => _analysisMode;
  List<String> get analysisFilterBattery => _analysisFilterBattery;
  List<String> get analysisFilterTrade => _analysisFilterTrade;
  List<String> get analysisFilterRank => _analysisFilterRank;

  // ── Setters ──────────────────────────────────────────────────────────────

  void setAnalysisMode(String mode) {
    _analysisMode = mode;
    notifyListeners();
  }

  void setAnalysisFilterBattery(List<String> battery) {
    _analysisFilterBattery = battery;
    notifyListeners();
  }

  void setAnalysisFilterTrade(List<String> trade) {
    _analysisFilterTrade = trade;
    notifyListeners();
  }

  void setAnalysisFilterRank(List<String> rank) {
    _analysisFilterRank = rank;
    notifyListeners();
  }

  void resetFilters() {
    _analysisFilterBattery = ['All'];
    _analysisFilterTrade = ['All'];
    _analysisFilterRank = ['All'];
    notifyListeners();
  }
}
