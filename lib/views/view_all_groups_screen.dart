import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/view_all_groups_viewmodel.dart';
import '../services/personnel_data_manager.dart';
import '../services/personnel_data.dart';
import '../services/mock_data.dart';
import 'group_detail_screen.dart';

class ViewAllGroupsScreen extends StatelessWidget {
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;

  const ViewAllGroupsScreen({
    super.key,
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ViewAllGroupsViewModel(),
      child: _ViewAllGroupsScreenContent(
        isDark: isDark,
        textThemeColor: textThemeColor,
        silverText: silverText,
        goldAccent: goldAccent,
        valueGreenColor: valueGreenColor,
      ),
    );
  }
}

class _ViewAllGroupsScreenContent extends StatelessWidget {
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;

  const _ViewAllGroupsScreenContent({
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
  });

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'travel':
        return Colors.blue.shade700;
      case 'training':
        return Colors.green.shade700;
      case 'sports':
        return Colors.purple.shade700;
      case 'working party':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getCategoryBgColor(String category) {
    switch (category.toLowerCase()) {
      case 'travel':
        return Colors.blue.shade100.withValues(alpha: 0.4);
      case 'training':
        return Colors.green.shade100.withValues(alpha: 0.4);
      case 'sports':
        return Colors.purple.shade100.withValues(alpha: 0.4);
      case 'working party':
        return Colors.red.shade100.withValues(alpha: 0.4);
      default:
        return Colors.grey.shade100.withValues(alpha: 0.4);
    }
  }

  Widget _buildCategoryChips(ViewAllGroupsViewModel viewModel) {
    final categories = ['All', 'Travel', 'Training', 'Sports', 'Working Party', 'Other'];
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = viewModel.selectedCategory.toLowerCase() == cat.toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (_) => viewModel.setSelectedCategory(cat),
              selectedColor: const Color(0xFF064420),
              backgroundColor: isDark ? const Color(0xFF0A2216) : Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? goldAccent : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, GroupModel group, ViewAllGroupsViewModel viewModel) {
    final catColor = _getCategoryColor(group.category);
    final catBg = _getCategoryBgColor(group.category);
    final dateStr = '${group.untilDate.year}-${group.untilDate.month.toString().padLeft(2, '0')}-${group.untilDate.day.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C5A32).withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? goldAccent.withValues(alpha: 0.2) : const Color(0xFF0C5A32).withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(
                  group: group,
                  isDark: isDark,
                  textThemeColor: textThemeColor,
                  silverText: silverText,
                  goldAccent: goldAccent,
                  valueGreenColor: valueGreenColor,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Category Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: TextStyle(
                          color: textThemeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: catBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        group.category,
                        style: TextStyle(
                          color: catColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Leader Info
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: goldAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Leader: ',
                      style: TextStyle(color: silverText, fontSize: 13),
                    ),
                    Expanded(
                      child: Text(
                        group.leaderName,
                        style: TextStyle(
                          color: textThemeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
                // Location Info
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: goldAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Location: ',
                      style: TextStyle(color: silverText, fontSize: 13),
                    ),
                    Expanded(
                      child: Text(
                        group.location,
                        style: TextStyle(
                          color: textThemeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),
                
                // Footer: Assigned count & Until date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group_outlined, color: valueGreenColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${group.assignedPersonnel.length} Personnel Assigned',
                          style: TextStyle(
                            color: textThemeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Until: $dateStr',
                      style: TextStyle(
                        color: silverText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ViewAllGroupsViewModel>();
    final filtered = viewModel.filteredGroups;

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE),
        body: Column(
          children: [
            // Solid dark green top header banner
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF064420), // Premium forest green
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // App Bar Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: goldAccent),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Group Management',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      style: const TextStyle(color: Colors.black87),
                      onChanged: (val) => viewModel.setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: 'Search groups by name or destination...',
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Category scroll list
            _buildCategoryChips(viewModel),
            const SizedBox(height: 8),
            // Group Cards List
            Expanded(
              child: viewModel.isLoading
                  ? Center(child: CircularProgressIndicator(color: goldAccent))
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No groups found',
                            style: TextStyle(color: silverText, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildGroupCard(context, filtered[index], viewModel);
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: MockDataManager().role == 'View-Only'
            ? null
            : _GroupSpeedDial(
                isDark: isDark,
                textThemeColor: textThemeColor,
                silverText: silverText,
                goldAccent: goldAccent,
                valueGreenColor: valueGreenColor,
                viewModel: viewModel,
              ),
      ),
    );
  }
}

class ManageMembersDialog extends StatefulWidget {
  final GroupModel group;
  final ViewAllGroupsViewModel viewModel;
  final Color goldAccent;
  final Color textThemeColor;
  final Color silverText;
  final bool isDark;

  const ManageMembersDialog({
    super.key,
    required this.group,
    required this.viewModel,
    required this.goldAccent,
    required this.textThemeColor,
    required this.silverText,
    required this.isDark,
  });

  @override
  State<ManageMembersDialog> createState() => _ManageMembersDialogState();
}

class _ManageMembersDialogState extends State<ManageMembersDialog> {
  final List<String> _selectedArmyNos = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedArmyNos.addAll(widget.group.assignedPersonnel);
  }

  @override
  Widget build(BuildContext context) {
    final allPersonnel = nominalRollList;
    final filteredPersonnel = allPersonnel.where((person) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (person['name'] ?? '').toLowerCase();
      final armyNo = (person['armyNo'] ?? '').toLowerCase();
      final rank = (person['rank'] ?? '').toLowerCase();
      return name.contains(q) || armyNo.contains(q) || rank.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manage Members',
                  style: TextStyle(
                    color: widget.textThemeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              widget.group.name,
              style: TextStyle(color: widget.goldAccent, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search personnel...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filteredPersonnel.length,
                itemBuilder: (context, index) {
                  final person = filteredPersonnel[index];
                  final armyNo = person['armyNo'] ?? '';
                  final name = person['name'] ?? '';
                  final rank = person['rank'] ?? '';
                  final isChecked = _selectedArmyNos.contains(armyNo);

                  return CheckboxListTile(
                    title: Text('$rank $name', style: TextStyle(color: widget.textThemeColor, fontSize: 13)),
                    subtitle: Text(armyNo, style: TextStyle(color: widget.silverText, fontSize: 11)),
                    value: isChecked,
                    activeColor: const Color(0xFF0C5A32),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          if (!_selectedArmyNos.contains(armyNo)) {
                            _selectedArmyNos.add(armyNo);
                          }
                        } else {
                          _selectedArmyNos.remove(armyNo);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C5A32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    widget.viewModel.updateGroupMembers(widget.group.id, _selectedArmyNos);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GroupFormDialog extends StatefulWidget {
  final GroupModel? group;
  final ViewAllGroupsViewModel viewModel;
  final Color goldAccent;
  final Color textThemeColor;
  final Color silverText;
  final bool isDark;

  const GroupFormDialog({
    super.key,
    this.group,
    required this.viewModel,
    required this.goldAccent,
    required this.textThemeColor,
    required this.silverText,
    required this.isDark,
  });

  @override
  State<GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<GroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late String _selectedCategory;
  String? _selectedLeaderArmyNo;
  late DateTime _untilDate;

  final List<String> _categories = ['Travel', 'Training', 'Sports', 'Working Party', 'Other'];

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameController = TextEditingController(text: g?.name ?? '');
    _locationController = TextEditingController(text: g?.location ?? '');
    _selectedCategory = g?.category ?? 'Travel';
    _selectedLeaderArmyNo = g?.leaderArmyNo;
    final roll = nominalRollList;
    if (_selectedLeaderArmyNo == null && roll.isNotEmpty) {
      _selectedLeaderArmyNo = roll.first['armyNo'];
    }
    _untilDate = g?.untilDate ?? DateTime.now().add(const Duration(days: 7));
  }

  String _getLeaderName(String armyNo) {
    final person = nominalRollList.firstWhere(
      (p) => p['armyNo'] == armyNo,
      orElse: () => {'rank': '', 'name': 'Unknown'},
    );
    final rank = person['rank'] ?? '';
    final name = person['name'] ?? '';
    return '$rank $name';
  }

  @override
  Widget build(BuildContext context) {
    final roll = nominalRollList;
    final isEdit = widget.group != null;
    final dateStr = '${_untilDate.year}-${_untilDate.month.toString().padLeft(2, '0')}-${_untilDate.day.toString().padLeft(2, '0')}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Group' : 'Create Group',
                style: TextStyle(
                  color: widget.textThemeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              
              // Group Name
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: widget.textThemeColor),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: TextStyle(color: widget.silverText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter group name' : null,
              ),
              const SizedBox(height: 12),
              
              // Location
              TextFormField(
                controller: _locationController,
                style: TextStyle(color: widget.textThemeColor),
                decoration: InputDecoration(
                  labelText: 'Location',
                  labelStyle: TextStyle(color: widget.silverText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter location' : null,
              ),
              const SizedBox(height: 12),
              
              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: widget.isDark ? const Color(0xFF0C5A32) : Colors.white,
                style: TextStyle(color: widget.textThemeColor),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: widget.silverText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              
              // Leader Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedLeaderArmyNo,
                dropdownColor: widget.isDark ? const Color(0xFF0C5A32) : Colors.white,
                style: TextStyle(color: widget.textThemeColor),
                decoration: InputDecoration(
                  labelText: 'Group Leader',
                  labelStyle: TextStyle(color: widget.silverText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: roll.map((person) {
                  final rank = person['rank'] ?? '';
                  final name = person['name'] ?? '';
                  final armyNo = person['armyNo'] ?? '';
                  return DropdownMenuItem<String>(
                    value: armyNo,
                    child: SizedBox(
                      width: 200,
                      child: Text(
                        '$rank $name ($armyNo)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedLeaderArmyNo = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Until Date Select
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Until Date', style: TextStyle(color: widget.silverText, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(dateStr, style: TextStyle(color: widget.textThemeColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.goldAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _untilDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _untilDate = picked;
                        });
                      }
                    },
                    child: const Text('Select Date'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C5A32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate() && _selectedLeaderArmyNo != null) {
                        final leaderName = _getLeaderName(_selectedLeaderArmyNo!);
                        if (isEdit) {
                          widget.viewModel.editGroup(
                            id: widget.group!.id,
                            name: _nameController.text,
                            category: _selectedCategory,
                            leaderArmyNo: _selectedLeaderArmyNo!,
                            leaderName: leaderName,
                            location: _locationController.text,
                            untilDate: _untilDate,
                            assignedPersonnel: widget.group!.assignedPersonnel,
                          );
                        } else {
                          widget.viewModel.createGroup(
                            name: _nameController.text,
                            category: _selectedCategory,
                            leaderArmyNo: _selectedLeaderArmyNo!,
                            leaderName: leaderName,
                            location: _locationController.text,
                            untilDate: _untilDate,
                          );
                        }
                        Navigator.pop(context);
                      }
                    },
                    child: Text(isEdit ? 'Save Changes' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Speed Dial FAB ────────────────────────────────────────────────────────────

class _GroupSpeedDial extends StatefulWidget {
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;
  final ViewAllGroupsViewModel viewModel;

  const _GroupSpeedDial({
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
    required this.viewModel,
  });

  @override
  State<_GroupSpeedDial> createState() => _GroupSpeedDialState();
}

class _GroupSpeedDialState extends State<_GroupSpeedDial>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animController;
  late Animation<double> _rotateAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.375).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _animController.reverse();
      });
    }
  }

  // ── dial item builder ────────────────────────────────────────────────────
  Widget _dialItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
    required int index,
  }) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animController,
          curve: Interval(0.1 * index, 1.0, curve: Curves.easeOut),
        )),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label chip
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _close();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF0C5A32).withValues(alpha: 0.9)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: widget.textThemeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Icon button
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {
                    _close();
                    onTap();
                  },
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF064420),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Dial Items (visible when open) ─────────────────────────────
        if (_isOpen) ...[
          // 1. Add New Group
          _dialItem(
            icon: Icons.add_circle_outline_rounded,
            label: 'Add Group',
            iconColor: widget.valueGreenColor,
            index: 1,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => GroupFormDialog(
                  viewModel: viewModel,
                  goldAccent: widget.goldAccent,
                  textThemeColor: widget.textThemeColor,
                  silverText: widget.silverText,
                  isDark: widget.isDark,
                ),
              );
            },
          ),

          // 2. Edit (first group in list as quick edit)
          _dialItem(
            icon: Icons.edit_outlined,
            label: 'Edit Group',
            iconColor: widget.goldAccent,
            index: 2,
            onTap: () {
              final groups = viewModel.filteredGroups;
              if (groups.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No group selected. Tap a group card to edit.')),
                );
                return;
              }
              // Show a picker to choose which group to edit
              showModalBottomSheet(
                context: context,
                backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Select Group to Edit',
                          style: TextStyle(
                            color: widget.textThemeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ...groups.map((g) => ListTile(
                            leading: Icon(Icons.edit_outlined, color: widget.goldAccent),
                            title: Text(g.name, style: TextStyle(color: widget.textThemeColor)),
                            subtitle: Text(g.category, style: TextStyle(color: widget.silverText, fontSize: 11)),
                            onTap: () {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => GroupFormDialog(
                                  group: g,
                                  viewModel: viewModel,
                                  goldAccent: widget.goldAccent,
                                  textThemeColor: widget.textThemeColor,
                                  silverText: widget.silverText,
                                  isDark: widget.isDark,
                                ),
                              );
                            },
                          )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),

          // 3. Delete Group
          _dialItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Group',
            iconColor: Colors.red.shade400,
            index: 3,
            onTap: () {
              final groups = viewModel.filteredGroups;
              if (groups.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No groups to delete.')),
                );
                return;
              }
              showModalBottomSheet(
                context: context,
                backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Select Group to Delete',
                          style: TextStyle(
                            color: widget.textThemeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ...groups.map((g) => ListTile(
                            leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            title: Text(g.name, style: TextStyle(color: widget.textThemeColor)),
                            subtitle: Text(g.category, style: TextStyle(color: widget.silverText, fontSize: 11)),
                            onTap: () {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
                                  title: Text('Delete Group', style: TextStyle(color: widget.textThemeColor)),
                                  content: Text(
                                    'Are you sure you want to delete "${g.name}"?',
                                    style: TextStyle(color: widget.textThemeColor),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        viewModel.deleteGroup(g.id);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),

          // 4. Add Person to Group
          _dialItem(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Add Person',
            iconColor: Colors.blue.shade300,
            index: 4,
            onTap: () {
              final groups = viewModel.filteredGroups;
              if (groups.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No groups available. Create a group first.')),
                );
                return;
              }
              showModalBottomSheet(
                context: context,
                backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Select Group to Add Person',
                          style: TextStyle(
                            color: widget.textThemeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ...groups.map((g) => ListTile(
                            leading: Icon(Icons.people_outline_rounded, color: widget.goldAccent),
                            title: Text(g.name, style: TextStyle(color: widget.textThemeColor)),
                            subtitle: Text(
                              '${g.assignedPersonnel.length} personnel',
                              style: TextStyle(color: widget.silverText, fontSize: 11),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (_) => ManageMembersDialog(
                                  group: g,
                                  viewModel: viewModel,
                                  goldAccent: widget.goldAccent,
                                  textThemeColor: widget.textThemeColor,
                                  silverText: widget.silverText,
                                  isDark: widget.isDark,
                                ),
                              );
                            },
                          )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ],

        // ── Main FAB ─────────────────────────────────────────────────────
        FloatingActionButton(
          backgroundColor: const Color(0xFF064420),
          foregroundColor: Colors.white,
          onPressed: _toggle,
          child: RotationTransition(
            turns: _rotateAnim,
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ],
    );
  }
}
