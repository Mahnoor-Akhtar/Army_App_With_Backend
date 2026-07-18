import 'package:flutter/foundation.dart';

/// ViewModel for the Edit tab inside the Dashboard.
/// Manages edit search query and all category/subcategory expansion sets.
/// Extracted from _DashboardScreenState in dashboard_screen.dart.
class EditTabViewModel extends ChangeNotifier {
  String _editSearchQuery = '';
  final Set<String> _expandedEditCategories = {};
  final Set<String> _expandedEditSubcategories = {};
  final Set<String> _expandedEditSubSubcategories = {};

  // ── Getters ─────────────────────────────────────────────────────────────

  String get editSearchQuery => _editSearchQuery;
  Set<String> get expandedEditCategories => _expandedEditCategories;
  Set<String> get expandedEditSubcategories => _expandedEditSubcategories;
  Set<String> get expandedEditSubSubcategories => _expandedEditSubSubcategories;

  bool isCategoryExpanded(String category) =>
      _expandedEditCategories.contains(category);
  bool isSubcategoryExpanded(String key) =>
      _expandedEditSubcategories.contains(key);
  bool isSubSubcategoryExpanded(String key) =>
      _expandedEditSubSubcategories.contains(key);

  // ── Setters / Actions ────────────────────────────────────────────────────

  void setEditSearchQuery(String query) {
    _editSearchQuery = query;
    notifyListeners();
  }

  void toggleCategory(String category) {
    if (_expandedEditCategories.contains(category)) {
      _expandedEditCategories.remove(category);
    } else {
      _expandedEditCategories.add(category);
    }
    notifyListeners();
  }

  void toggleSubcategory(String key) {
    if (_expandedEditSubcategories.contains(key)) {
      _expandedEditSubcategories.remove(key);
    } else {
      _expandedEditSubcategories.add(key);
    }
    notifyListeners();
  }

  void toggleSubSubcategory(String key) {
    if (_expandedEditSubSubcategories.contains(key)) {
      _expandedEditSubSubcategories.remove(key);
    } else {
      _expandedEditSubSubcategories.add(key);
    }
    notifyListeners();
  }

  void collapseAll() {
    _expandedEditCategories.clear();
    _expandedEditSubcategories.clear();
    _expandedEditSubSubcategories.clear();
    notifyListeners();
  }
}
