import 'package:flutter/foundation.dart';
import '../services/personnel_data_manager.dart';
import '../services/supabase_repository.dart';

/// ViewModel for the Edit Assignment screen.
/// Manages category/subcategory/sub-subcategory selection and date state.
/// Extracted from _EditAssignmentScreenState in edit_assignment_screen.dart.
class EditAssignmentViewModel extends ChangeNotifier {
  final PersonnelDataManager _dataManager = PersonnelDataManager();
  final SupabaseRepository _supabaseRepo = SupabaseRepository();
  final Map<String, String> person;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  late String _selectedCategory;
  String? _selectedSubcategory;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _destination;

  List<String> _categories = [];
  List<String> _subcategories = [];
  Map<String, dynamic> _statusHierarchy = {};

  // ── Getters ─────────────────────────────────────────────────────────────

  String get selectedCategory => _selectedCategory;
  String? get selectedSubcategory => _selectedSubcategory;
  DateTime get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get destination => _destination;
  List<String> get categories => _categories;
  List<String> get subcategories => _subcategories;

  // ── Constructor ──────────────────────────────────────────────────────────

  EditAssignmentViewModel({required this.person}) {
    _init();
  }

  Future<void> _init() async {
    final armyNo = person['armyNo'] ?? '';
    final currentStatus = _dataManager.getStatus(armyNo);

    _selectedCategory = currentStatus.category;
    _selectedSubcategory = currentStatus.subcategory;
    _destination = currentStatus.destination;

    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    final initialEndDate = currentStatus.endDate;
    _endDate = initialEndDate != null
        ? DateTime(initialEndDate.year, initialEndDate.month, initialEndDate.day)
        : null;

    // Load status hierarchy from Supabase
    try {
      _statusHierarchy = await _supabaseRepo.getStatusHierarchy();
      // Deduplicate categories
      final uniqueCats = <String>{};
      _categories = _statusHierarchy.keys.where((k) => uniqueCats.add(k)).toList();
    } catch (e) {
      // Fallback to empty hierarchy if Supabase fails
      _statusHierarchy = {};
      _categories = [];
    }

    _updateDropdownLists(initial: true);
    _isLoading = false;
    notifyListeners();
  }

  // ── Dropdown list management ─────────────────────────────────────────────

  void _updateDropdownLists({bool initial = false}) {
    final categoryData = _statusHierarchy[_selectedCategory];

    if (categoryData == null) {
      _subcategories = [];
      if (!initial) {
        _selectedSubcategory = null;
      }
    } else if (categoryData is List<String>) {
      // Deduplicate subcategories
      final uniqueSubs = <String>{};
      _subcategories = categoryData.where((s) => uniqueSubs.add(s)).toList();
      if (!initial ||
          (_selectedSubcategory != null &&
              !_subcategories.contains(_selectedSubcategory))) {
        _selectedSubcategory = _subcategories.isNotEmpty ? _subcategories.first : null;
      }
    } else if (categoryData is Map<String, dynamic>) {
      // Deduplicate subcategories
      final uniqueSubs = <String>{};
      _subcategories = categoryData.keys.where((s) => uniqueSubs.add(s)).toList();
      if (!initial ||
          (_selectedSubcategory != null &&
              !_subcategories.contains(_selectedSubcategory))) {
        _selectedSubcategory = _subcategories.isNotEmpty ? _subcategories.first : null;
      }
    }
  }

  // ── Setters ──────────────────────────────────────────────────────────────

  void setCategory(String category) {
    _selectedCategory = category;
    _updateDropdownLists();
    notifyListeners();
  }

  void setSubcategory(String? subcategory) {
    _selectedSubcategory = subcategory;
    notifyListeners();
  }

  void setStartDate(DateTime date) {
    _startDate = date;
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      _endDate = _startDate.add(const Duration(days: 7));
    }
    notifyListeners();
  }

  void setEndDate(DateTime? date) {
    _endDate = date;
    notifyListeners();
  }

  void setDestination(String? destination) {
    _destination = destination;
    notifyListeners();
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> saveAssignment() async {
    final armyNo = person['armyNo'] ?? '';
    final newStatus = PersonStatus(
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      startDate: _startDate,
      endDate: _endDate,
      destination: _destination,
    );
    await _dataManager.updateStatus(armyNo, newStatus);
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  String formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}
