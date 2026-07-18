import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/edit_assignment_viewmodel.dart';

class EditAssignmentScreen extends StatelessWidget {
  final Map<String, String> person;
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;
  final VoidCallback onSaved;

  const EditAssignmentScreen({
    super.key,
    required this.person,
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditAssignmentViewModel(person: person),
      child: _EditAssignmentScreenContent(
        person: person,
        isDark: isDark,
        textThemeColor: textThemeColor,
        silverText: silverText,
        goldAccent: goldAccent,
        valueGreenColor: valueGreenColor,
        onSaved: onSaved,
      ),
    );
  }
}

class _EditAssignmentScreenContent extends StatelessWidget {
  final Map<String, String> person;
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;
  final VoidCallback onSaved;

  const _EditAssignmentScreenContent({
    required this.person,
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
    required this.onSaved,
  });

  Future<void> _selectStartDate(BuildContext context) async {
    final viewModel = context.read<EditAssignmentViewModel>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.startDate.isBefore(today) ? today : viewModel.startDate,
      firstDate: today,
      lastDate: DateTime(2030),
      builder: (context, child) => _buildDatePickerTheme(context, child!),
    );
    if (picked != null) {
      viewModel.setStartDate(picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final viewModel = context.read<EditAssignmentViewModel>();
    final initialDate = (viewModel.endDate != null && viewModel.endDate!.isAfter(viewModel.startDate))
        ? viewModel.endDate!
        : viewModel.startDate.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: viewModel.startDate,
      lastDate: DateTime(2030),
      builder: (context, child) => _buildDatePickerTheme(context, child!),
    );
    if (picked != null) {
      viewModel.setEndDate(picked);
    }
  }

  Widget _buildDatePickerTheme(BuildContext context, Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.dark(
          primary: goldAccent,
          onPrimary: Colors.black,
          surface: const Color(0xFF0A2214),
          onSurface: Colors.white,
        ),
      ),
      child: child,
    );
  }

  void _saveAssignment(BuildContext context) {
    final viewModel = context.read<EditAssignmentViewModel>();
    viewModel.saveAssignment();
    onSaved();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Assignment Updated for ${person['name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0C5A32),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EditAssignmentViewModel>();
    final rank = person['rank'] ?? '';
    final name = person['name'] ?? '';
    final armyNo = person['armyNo'] ?? '';

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF03140A).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: goldAccent),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'EDIT PERSONNEL ASSIGNMENT',
            style: TextStyle(
              color: textThemeColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          centerTitle: true,
        ),
        body: viewModel.isLoading
            ? Center(child: CircularProgressIndicator(color: goldAccent))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. PERSONNEL INFO SUMMARY CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF051C0F), const Color(0xFF0C3D21)]
                              : [Colors.white, const Color(0xFFE8F5EE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: goldAccent.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: goldAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: goldAccent.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                rank,
                                style: TextStyle(
                                  color: goldAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: textThemeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: valueGreenColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: valueGreenColor.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    armyNo,
                                    style: TextStyle(
                                      color: valueGreenColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. INPUT FORM CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0C5A32).withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? goldAccent.withValues(alpha: 0.25) : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ASSIGNMENT DETAILS',
                            style: TextStyle(
                              color: goldAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const Divider(height: 20, thickness: 0.5),

                          // Primary Category
                          _buildFormLabel('Primary Category'),
                          _buildDropdown<String>(
                            value: viewModel.selectedCategory,
                            items: viewModel.categories,
                            onChanged: (val) {
                              if (val != null) {
                                viewModel.setCategory(val);
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // Subcategory (if applicable)
                          if (viewModel.subcategories.isNotEmpty) ...[
                            _buildFormLabel('Subcategory'),
                            _buildDropdown<String>(
                              value: viewModel.selectedSubcategory,
                              items: viewModel.subcategories,
                              onChanged: (val) {
                                if (val != null) {
                                  viewModel.setSubcategory(val);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Sub-subcategory (if applicable)
                          if (viewModel.subSubcategories.isNotEmpty) ...[
                            _buildFormLabel('Sub-subcategory Detail'),
                            _buildDropdown<String>(
                              value: viewModel.selectedSubSubcategory,
                              items: viewModel.subSubcategories,
                              onChanged: (val) {
                                if (val != null) {
                                  viewModel.setSubSubcategory(val);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Start Date & End Date Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFormLabel('Start Date'),
                                    GestureDetector(
                                      onTap: () => _selectStartDate(context),
                                      child: _buildDateDisplay(viewModel.formatDate(viewModel.startDate)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildFormLabel('End Date'),
                                        if (viewModel.endDate != null)
                                          GestureDetector(
                                            onTap: () {
                                              viewModel.setEndDate(null);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 6.0, right: 2.0),
                                              child: Text(
                                                'Set Infinite',
                                                style: TextStyle(
                                                  color: goldAccent,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () => _selectEndDate(context),
                                      child: _buildDateDisplay(
                                        viewModel.endDate != null ? viewModel.formatDate(viewModel.endDate!) : 'Infinite',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (viewModel.selectedCategory == 'Leave') ...[
                            const SizedBox(height: 14),
                            _buildFormLabel('Destination / Place of Leave'),
                            TextFormField(
                              initialValue: viewModel.destination,
                              onChanged: (val) {
                                viewModel.setDestination(val.trim().isEmpty ? null : val.trim());
                              },
                              style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'Enter city, address or location',
                                hintStyle: TextStyle(color: silverText.withOpacity(0.5), fontSize: 12),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE).withOpacity(0.5),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: goldAccent.withOpacity(0.3), width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: goldAccent, width: 1.5),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // SAVE BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => _saveAssignment(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0C5A32),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: goldAccent.withOpacity(0.5), width: 1),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'SAVE ASSIGNMENT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFormLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 2.0),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDark ? const Color(0xFF8B9B90) : const Color(0xFF4A5D52),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    // Handle case where value isn't in items
    final effectiveValue = (value != null && items.contains(value)) ? value : (items.isNotEmpty ? items.first : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: goldAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: effectiveValue,
          isExpanded: true,
          onChanged: onChanged,
          dropdownColor: isDark ? const Color(0xFF0A2214) : Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: goldAccent),
          style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
          items: items.map<DropdownMenuItem<T>>((T val) {
            return DropdownMenuItem<T>(
              value: val,
              child: Text(val.toString()),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDateDisplay(String formattedText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: goldAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formattedText,
            style: TextStyle(
              color: textThemeColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(Icons.calendar_month_rounded, color: goldAccent, size: 18),
        ],
      ),
    );
  }
}
