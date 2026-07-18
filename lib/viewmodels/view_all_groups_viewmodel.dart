import 'package:flutter/foundation.dart';
import '../services/personnel_data_manager.dart';

class ViewAllGroupsViewModel extends ChangeNotifier {
  final PersonnelDataManager _dataManager = PersonnelDataManager();
  List<GroupModel> _allGroups = [];
  bool isLoading = true;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  ViewAllGroupsViewModel() {
    loadGroups();
  }

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  void loadGroups() {
    isLoading = true;
    notifyListeners();
    
    _allGroups = _dataManager.customGroups;
    
    isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  List<GroupModel> get filteredGroups {
    return _allGroups.where((group) {
      // 1. Category Filter
      if (_selectedCategory != 'All' && group.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      // 2. Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = group.name.toLowerCase().contains(query);
        final locationMatch = group.location.toLowerCase().contains(query);
        final leaderMatch = group.leaderName.toLowerCase().contains(query);
        return nameMatch || locationMatch || leaderMatch;
      }
      return true;
    }).toList();
  }

  void createGroup({
    required String name,
    required String category,
    required String leaderArmyNo,
    required String leaderName,
    required String location,
    required DateTime untilDate,
  }) {
    final newGroup = GroupModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      category: category,
      leaderArmyNo: leaderArmyNo,
      leaderName: leaderName,
      location: location,
      assignedPersonnel: [],
      untilDate: untilDate,
    );
    _dataManager.addCustomGroup(newGroup);
    loadGroups();
  }

  void editGroup({
    required String id,
    required String name,
    required String category,
    required String leaderArmyNo,
    required String leaderName,
    required String location,
    required DateTime untilDate,
    required List<String> assignedPersonnel,
  }) {
    final updated = GroupModel(
      id: id,
      name: name,
      category: category,
      leaderArmyNo: leaderArmyNo,
      leaderName: leaderName,
      location: location,
      assignedPersonnel: assignedPersonnel,
      untilDate: untilDate,
    );
    _dataManager.updateCustomGroup(updated);
    loadGroups();
  }

  void deleteGroup(String id) {
    _dataManager.deleteCustomGroup(id);
    loadGroups();
  }

  void updateGroupMembers(String groupId, List<String> armyNos) {
    final index = _allGroups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      final updated = _allGroups[index].copyWith(assignedPersonnel: armyNos);
      _dataManager.updateCustomGroup(updated);
      loadGroups();
    }
  }
}
