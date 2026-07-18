import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/manage_attributes_viewmodel.dart';

class ManageAttributesScreen extends StatelessWidget {
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;

  const ManageAttributesScreen({
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
      create: (_) => ManageAttributesViewModel(),
      child: _ManageAttributesScreenContent(
        isDark: isDark,
        textThemeColor: textThemeColor,
        silverText: silverText,
        goldAccent: goldAccent,
        valueGreenColor: valueGreenColor,
      ),
    );
  }
}

class _ManageAttributesScreenContent extends StatefulWidget {
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;

  const _ManageAttributesScreenContent({
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
  });

  @override
  State<_ManageAttributesScreenContent> createState() => _ManageAttributesScreenContentState();
}

class _ManageAttributesScreenContentState extends State<_ManageAttributesScreenContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditDialog(BuildContext context, String type, {String? existingValue, int? index}) {
    final viewModel = context.read<ManageAttributesViewModel>();
    final TextEditingController controller = TextEditingController(
      text: type == 'Rank' && existingValue != null ? existingValue.trim() : existingValue,
    );

    String selectedType = 'Subcategory';
    String? selectedParent;
    final List<String> categories = viewModel.ranks
        .where((r) => r.toLowerCase() != 'all' && !r.startsWith(' '))
        .toList();

    if (type == 'Rank') {
      if (existingValue != null) {
        if (existingValue.startsWith(' ')) {
          selectedType = 'Subcategory';
          String? foundParent;
          for (int i = index! - 1; i >= 0; i--) {
            if (!viewModel.ranks[i].startsWith(' ') &&
                viewModel.ranks[i].toLowerCase() != 'all') {
              foundParent = viewModel.ranks[i];
              break;
            }
          }
          selectedParent = foundParent;
        } else {
          selectedType = 'Category';
        }
      } else {
        selectedType = categories.isNotEmpty ? 'Subcategory' : 'Category';
      }
      if (selectedParent == null && categories.isNotEmpty) {
        selectedParent = categories.first;
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
              title: Text(
                existingValue == null ? 'Add New $type' : 'Edit $type',
                style: TextStyle(color: widget.textThemeColor, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 'Rank' && categories.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Subcategory', style: TextStyle(fontSize: 12)),
                            value: 'Subcategory',
                            groupValue: selectedType,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedType = val);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Category', style: TextStyle(fontSize: 12)),
                            value: 'Category',
                            groupValue: selectedType,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedType = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (selectedType == 'Subcategory') ...[
                      const SizedBox(height: 8),
                      const Text('Parent Category:',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: selectedParent,
                        isExpanded: true,
                        dropdownColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
                        style: TextStyle(color: widget.textThemeColor, fontSize: 12),
                        items: categories
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedParent = val);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: controller,
                    style: TextStyle(color: widget.textThemeColor),
                    decoration: InputDecoration(
                      hintText: type == 'Rank'
                          ? (selectedType == 'Category' ? 'Enter Category name' : 'Enter Rank name')
                          : 'Enter $type name',
                      hintStyle: TextStyle(color: widget.silverText),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: widget.goldAccent.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: widget.goldAccent)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: TextStyle(color: widget.silverText)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final val = controller.text.trim();
                    if (val.isEmpty) return;
                    Navigator.pop(dialogContext);

                    if (type == 'Trade') {
                      if (existingValue != null && index != null) {
                        await viewModel.editTrade(index, val);
                      } else {
                        await viewModel.addTrade(val);
                      }
                    } else if (type == 'Battery') {
                      if (existingValue != null && index != null) {
                        await viewModel.editBattery(index, val);
                      } else {
                        await viewModel.addBattery(val);
                      }
                    } else if (type == 'Rank') {
                      if (existingValue != null && index != null) {
                        await viewModel.editRank(
                          index: index,
                          value: val,
                          selectedType: selectedType,
                          selectedParent: selectedParent,
                        );
                      } else {
                        await viewModel.addRank(
                          value: val,
                          selectedType: selectedType,
                          selectedParent: selectedParent,
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: widget.goldAccent),
                  child: const Text('Save',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteAttribute(BuildContext context, String type, int index) {
    final viewModel = context.read<ManageAttributesViewModel>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
        title: Text('Delete $type',
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this $type?',
            style: TextStyle(color: widget.textThemeColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: widget.silverText)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (type == 'Trade') await viewModel.deleteTrade(index);
              else if (type == 'Rank') await viewModel.deleteRank(index);
              else if (type == 'Battery') await viewModel.deleteBattery(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, String type, List<String> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isAll = item.toLowerCase() == 'all';

        final isSub = type == 'Rank' && item.startsWith(' ');
        final displayText = isSub ? item.trim() : item;
        final isCategoryHeader = type == 'Rank' && !isSub && !isAll;

        return Padding(
          padding: EdgeInsets.only(left: isSub ? 20.0 : 0.0),
          child: Card(
            color: isCategoryHeader
                ? (widget.isDark
                    ? const Color(0xFF0C5A32).withValues(alpha: 0.2)
                    : const Color(0xFFE8F5EE))
                : (widget.isDark
                    ? const Color(0xFF0C5A32).withValues(alpha: 0.1)
                    : Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isCategoryHeader
                    ? widget.goldAccent
                    : widget.goldAccent.withValues(alpha: 0.3),
                width: isCategoryHeader ? 1.2 : 1.0,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: isSub
                  ? Icon(Icons.subdirectory_arrow_right,
                      color: widget.goldAccent.withValues(alpha: 0.7), size: 16)
                  : null,
              title: Text(
                displayText,
                style: TextStyle(
                  color: isAll
                      ? widget.goldAccent
                      : (isCategoryHeader ? widget.goldAccent : widget.textThemeColor),
                  fontWeight: (isAll || isCategoryHeader)
                      ? FontWeight.bold
                      : FontWeight.w500,
                  fontSize: isCategoryHeader ? 14 : 13,
                ),
              ),
              trailing: isAll
                  ? const SizedBox.shrink()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: widget.valueGreenColor, size: 20),
                          onPressed: () => _showAddEditDialog(context, type,
                              existingValue: item, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteAttribute(context, type, index),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ManageAttributesViewModel>();

    return Theme(
      data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: widget.isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE),
        appBar: AppBar(
          backgroundColor: widget.isDark
              ? const Color(0xFF03140A).withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.85),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: widget.goldAccent),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Manage App Attributes',
            style: TextStyle(
              color: widget.textThemeColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: widget.goldAccent,
            labelColor: widget.goldAccent,
            unselectedLabelColor: widget.silverText,
            tabs: const [
              Tab(text: 'Trades'),
              Tab(text: 'Ranks'),
              Tab(text: 'Batteries'),
            ],
          ),
        ),
        body: viewModel.isLoading
            ? Center(child: CircularProgressIndicator(color: widget.goldAccent))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(context, 'Trade', viewModel.trades),
                  _buildList(context, 'Rank', viewModel.ranks),
                  _buildList(context, 'Battery', viewModel.batteries),
                ],
              ),
        floatingActionButton: viewModel.isLoading
            ? null
            : FloatingActionButton(
                onPressed: () {
                  final idx = _tabController.index;
                  final type = idx == 0
                      ? 'Trade'
                      : idx == 1
                          ? 'Rank'
                          : 'Battery';
                  _showAddEditDialog(context, type);
                },
                backgroundColor: widget.goldAccent,
                child: const Icon(Icons.add, color: Colors.black),
              ),
      ),
    );
  }
}
