// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' show ImageFilter;
import 'package:csv/csv.dart' as csv;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../services/file_saver.dart';
import 'splash_screen.dart'; // Reuse TopographicPainter
import '../services/mock_data.dart';
import '../services/personnel_data.dart';
import '../services/personnel_data_manager.dart';
import 'edit_assignment_screen.dart';
import 'battery_detail_screen.dart';
import 'manage_attributes_screen.dart';
import 'view_all_groups_screen.dart';
import '../widgets/movement_history_widget.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/nominal_roll_viewmodel.dart';
import '../viewmodels/analysis_viewmodel.dart';
import 'personnel_profile_screen.dart';
import '../viewmodels/edit_tab_viewmodel.dart';
import '../models/status_history.dart';
import '../services/supabase_repository.dart';
import 'package:open_file/open_file.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const DashboardScreen({
    super.key,
    required this.onLogout,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // Pure animation controller — stays local, not business logic
  late AnimationController _bgAnimationController;

  // TextEditingControllers stay local (they are UI concerns); they push
  // updates into the appropriate ViewModels.
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _rollSearchController = TextEditingController();
  final TextEditingController _editSearchController = TextEditingController();
  final TextEditingController _settingsAdminUsernameController =
      TextEditingController();

  // Attendance filter state variables
  String _filterCategory = 'Leave';
  final List<String> _filterSelectedSubcategories = [];
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  final TextEditingController _filterDestinationController = TextEditingController();
  String _filterDestinationQuery = '';

  // ── ViewModel convenience getters ──────────────────────────────────────
  // Read-only helpers so the rest of the 10k-line build method keeps
  // exactly the same property names it used before.

  DashboardViewModel get _dashVM =>
      context.read<DashboardViewModel>();
  NominalRollViewModel get _rollVM =>
      context.read<NominalRollViewModel>();
  AnalysisViewModel get _analysisVM =>
      context.read<AnalysisViewModel>();
  EditTabViewModel get _editVM =>
      context.read<EditTabViewModel>();

  // Property aliases — delegate to ViewModels so every existing reference
  // in the build tree continues to compile without change.
  int get _selectedTabIndex => context.read<DashboardViewModel>().selectedTabIndex;
  set _selectedTabIndex(int val) => _dashVM.setSelectedTabIndex(val);

  String get _searchQuery => context.read<DashboardViewModel>().searchQuery;

  Set<String> get _expandedSections => context.read<DashboardViewModel>().expandedSections;

  bool get _isFabMenuOpen => context.read<DashboardViewModel>().isFabMenuOpen;
  set _isFabMenuOpen(bool val) => _dashVM.setFabMenuOpen(val);

  bool get _isRollFabMenuOpen => context.read<DashboardViewModel>().isRollFabMenuOpen;
  set _isRollFabMenuOpen(bool val) => _dashVM.setRollFabMenuOpen(val);

  bool get _isRollEditMode => context.read<DashboardViewModel>().isRollEditMode;
  set _isRollEditMode(bool val) => _dashVM.setRollEditMode(val);

  bool get _isRollDeleteMode => context.read<DashboardViewModel>().isRollDeleteMode;
  set _isRollDeleteMode(bool val) => _dashVM.setRollDeleteMode(val);

  List<String> get _tradesList => context.read<DashboardViewModel>().tradesList;
  List<String> get _ranksList => context.read<DashboardViewModel>().ranksList;
  List<String> get _batteriesList => context.read<DashboardViewModel>().batteriesList;
  bool get _canAccessEditTab => context.read<DashboardViewModel>().canAccessEditTab;
  bool get _canAccessFABs => context.read<DashboardViewModel>().canAccessFABs;

  void _loadDynamicAttributes() => _dashVM.refreshAttributes();

  String get _rollSearchQuery => context.read<NominalRollViewModel>().rollSearchQuery;

  String get _selectedDivision => context.read<NominalRollViewModel>().selectedDivision;
  set _selectedDivision(String val) => _rollVM.setSelectedDivision(val);

  String get _selectedBattery => context.read<NominalRollViewModel>().selectedBattery;
  set _selectedBattery(String val) => _rollVM.setSelectedBattery(val);

  String get _selectedRankCategory => context.read<NominalRollViewModel>().selectedRankCategory;
  set _selectedRankCategory(String val) => _rollVM.setSelectedRankCategory(val);

  String get _selectedTrade => context.read<NominalRollViewModel>().selectedTrade;
  set _selectedTrade(String val) => _rollVM.setSelectedTrade(val);

  String get _analysisMode => context.read<AnalysisViewModel>().analysisMode;
  set _analysisMode(String val) => _analysisVM.setAnalysisMode(val);

  List<String> get _analysisFilterBattery => context.read<AnalysisViewModel>().analysisFilterBattery;
  set _analysisFilterBattery(List<String> val) => _analysisVM.setAnalysisFilterBattery(val);

  List<String> get _analysisFilterTrade => context.read<AnalysisViewModel>().analysisFilterTrade;
  set _analysisFilterTrade(List<String> val) => _analysisVM.setAnalysisFilterTrade(val);

  List<String> get _analysisFilterRank => context.read<AnalysisViewModel>().analysisFilterRank;
  set _analysisFilterRank(List<String> val) => _analysisVM.setAnalysisFilterRank(val);

  String get _editSearchQuery => context.read<EditTabViewModel>().editSearchQuery;
  Set<String> get _expandedEditCategories => context.read<EditTabViewModel>().expandedEditCategories;
  Set<String> get _expandedEditSubcategories => context.read<EditTabViewModel>().expandedEditSubcategories;
  Set<String> get _expandedEditSubSubcategories => context.read<EditTabViewModel>().expandedEditSubSubcategories;

  @override
  void initState() {
    super.initState();
    // Continuous drifting animation for background topographic lines
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);

    // Text controllers push changes into ViewModels; no setState needed here.
    _searchController.addListener(() {
      _dashVM.setSearchQuery(_searchController.text.trim().toLowerCase());
    });

    _rollSearchController.addListener(() {
      _rollVM.setRollSearchQuery(_rollSearchController.text.trim().toLowerCase());
    });

    _editSearchController.addListener(() {
      _editVM.setEditSearchQuery(_editSearchController.text.trim().toLowerCase());
    });

    _filterDestinationController.addListener(() {
      setState(() {
        _filterDestinationQuery = _filterDestinationController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _searchController.dispose();
    _rollSearchController.dispose();
    _editSearchController.dispose();
    _settingsAdminUsernameController.dispose();
    _filterDestinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch ViewModels to rebuild widget when they notify changes
    context.watch<DashboardViewModel>();
    context.watch<NominalRollViewModel>();
    context.watch<AnalysisViewModel>();
    context.watch<EditTabViewModel>();

    final maxTabs = 5;
    if (_selectedTabIndex >= maxTabs) {
      _selectedTabIndex = 0;
    }

    final size = MediaQuery.of(context).size;
    final isDark = widget.isDarkMode;

    // Theme Colors refined for maximum visibility in both Light and Dark modes
    final bgColor = isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE);
    final textThemeColor = isDark ? Colors.white : const Color(0xFF042011);
    final silverText = isDark
        ? const Color(0xFFE5E5E5)
        : const Color(0xFF4A5D52);
    final goldAccent = isDark
        ? const Color(0xFFCD9B2D)
        : const Color(0xFF9E7715);
    final neonGreen = const Color(0xFF00FF66);
    final valueGreenColor = isDark ? neonGreen : const Color(0xFF0C5A32);

    final manager = PersonnelDataManager();
    // Filter categories based on search input and populate count dynamically
    final filteredCategories = manager.categoryHierarchy.keys
        .map((name) {
          return {'name': name, 'count': manager.getCountForCategory(name)};
        })
        .where((cat) {
          return cat['name'].toString().toLowerCase().contains(_searchQuery);
        })
        .toList();

    return PopScope(
      canPop: _selectedTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _selectedTabIndex = 0;
        });
      },
      child: Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar:
          true, // Enables content to scroll behind glass app bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0.0,
          backgroundColor: isDark
              ? const Color(0xFF03140A).withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.92),
          shadowColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFFCD9B2D).withValues(alpha: 0.25)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? const [
                            Color(0xFFFFF2C2),
                            Color(0xFFE9C54F),
                            Color(0xFFFFFFFF),
                          ]
                        : const [
                            Color(0xFF042011),
                            Color(0xFF0C5A32),
                            Color(0xFF042011),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'ZARB-UL-HADEED',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF042011),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '117 SP REGT.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFE5E5E5)
                        : const Color(0xFF4A5D52),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Theme Switcher
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: isDark ? Colors.white : const Color(0xFF0C5A32),
                  size: 22,
                ),
                onPressed: widget.onToggleTheme,
                tooltip: isDark
                    ? 'Switch to Light Theme'
                    : 'Switch to Dark Theme',
              ),
            ),

            // Notification bell with neon badge
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 4.0),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    color: isDark ? Colors.white : const Color(0xFF0C5A32),
                    size: 24,
                  ),
                  Positioned(
                    top: 2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: Color(
                          0xFF00FF66,
                        ), // Neon Green always on dark app bar
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Profile avatar with menu
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 16.0),
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') {
                    MockDataManager().logout();
                    widget.onLogout();
                  }
                },
                offset: const Offset(0, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFCD9B2D), width: 1),
                ),
                color: isDark
                    ? const Color(0xFF0A2214)
                    : const Color(0xFFE2EFE9),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) {
                            final adminArmyNo = MockDataManager().adminArmyNo ?? '';
                            final adminPerson = nominalRollList.firstWhere(
                              (p) => p['armyNo'] == adminArmyNo,
                              orElse: () => <String, String>{},
                            );
                            final adminAvatar = adminPerson['avatar'] ?? '';
                            return Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFCD9B2D).withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: ClipOval(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: _buildAvatarImage(adminAvatar),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          MockDataManager().username != null
                              ? MockDataManager().username!.toUpperCase()
                              : 'ADMIN',
                          style: TextStyle(
                            color: textThemeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: silverText,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          MockDataManager().role ?? 'Administrator',
                          style: TextStyle(color: silverText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Builder(
                  builder: (context) {
                    // Find logged-in user's profile photo from nominalRollList
                    final adminArmyNo = MockDataManager().adminArmyNo ?? '';
                    final adminPerson = nominalRollList.firstWhere(
                      (p) => p['armyNo'] == adminArmyNo,
                      orElse: () => <String, String>{},
                    );
                    final adminAvatar = adminPerson['avatar'] ?? '';

                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFCD9B2D).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: _buildAvatarImage(adminAvatar),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Dynamic Topographic background
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(size.width, size.height),
                painter: TopographicPainter(
                  animationValue: _bgAnimationController.value,
                ),
              );
            },
          ),

          // 2. Spotlight glow behind summary stats (only in Dark Mode)
          if (isDark)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      const Color(0xFF0C5A32).withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // 3. Scrollable content area
          SafeArea(
            top: false, // Allows background to paint behind translucent AppBar
            child: _selectedTabIndex == 0
                ? Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          // Top padding pushes contents below the glass app bar initially
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 80.0,
                            left: 20.0,
                            right: 20.0,
                            bottom: 100.0,
                          ),
                          child: Column(
                            children: [
                              // SUMMARY STATS CARD (Overall glass-morphism header)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18.0,
                                  horizontal: 14.0,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(
                                          0xFF0C5A32,
                                        ).withValues(alpha: 0.18)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? goldAccent.withValues(alpha: 0.35)
                                        : const Color(
                                            0xFF0C5A32,
                                          ).withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.2)
                                          : const Color(
                                              0xFF0C5A32,
                                            ).withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    // Total Stats (Gold)
                                    _buildSummaryItem(
                                      label: 'TOTAL',
                                      value: '${nominalRollList.length}',
                                      valueColor: goldAccent,
                                      labelColor: silverText,
                                    ),
                                    _buildSummaryDivider(goldAccent, isDark),
                                    // Fighting Stats (Neon Green / Deep Emerald)
                                    _buildSummaryItem(
                                      label: 'FIGHTING',
                                      value:
                                          '${nominalRollList.where((p) => _isFighting(p)).length}',
                                      valueColor: valueGreenColor,
                                      labelColor: silverText,
                                    ),
                                    _buildSummaryDivider(goldAccent, isDark),
                                    // Non Fighting Stats (Gold / Deep Emerald)
                                    _buildSummaryItem(
                                      label: 'NON FIGHTING',
                                      value:
                                          '${nominalRollList.where((p) => !_isFighting(p)).length}',
                                      valueColor: valueGreenColor,
                                      labelColor: silverText,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),

                              // categories grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 2.6,
                                    ),
                                padding: EdgeInsets.zero,
                                itemCount: filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final cat = filteredCategories[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CategoryPersonnelListScreen(
                                                categoryName:
                                                    cat['name'] as String,
                                                isDark: isDark,
                                                textThemeColor: textThemeColor,
                                                silverText: silverText,
                                                goldAccent: goldAccent,
                                                valueGreenColor:
                                                    valueGreenColor,
                                                getPersonStatus:
                                                    _getPersonStatus,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(
                                                0xFF0C5A32,
                                              ).withValues(alpha: 0.12)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? goldAccent.withValues(
                                                  alpha: 0.25,
                                                )
                                              : const Color(
                                                  0xFF0C5A32,
                                                ).withValues(alpha: 0.18),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isDark
                                                ? Colors.black.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : const Color(
                                                    0xFF0C5A32,
                                                  ).withValues(alpha: 0.03),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 5,
                                              color: goldAccent,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    cat['name'] as String,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: textThemeColor,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Strength',
                                                    style: TextStyle(
                                                      color: silverText,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 14.0,
                                              ),
                                              child: Text(
                                                '${cat['count']}',
                                                style: TextStyle(
                                                  color: valueGreenColor,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  fontFamily: 'serif',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 15),

                              // PERSONNEL NAME SEARCH RESULTS
                              if (_searchQuery.isNotEmpty) ...(() {
                                final matchedPersonnel = nominalRollList.where((person) {
                                  final name = (person['name'] ?? '').toLowerCase();
                                  final armyNo = (person['armyNo'] ?? '').toLowerCase();
                                  final rank = (person['rank'] ?? '').toLowerCase();
                                  return name.contains(_searchQuery) ||
                                      armyNo.contains(_searchQuery) ||
                                      rank.contains(_searchQuery);
                                }).toList();

                                if (matchedPersonnel.isEmpty) return <Widget>[];

                                return [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_search_rounded,
                                            size: 16, color: goldAccent),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Personnel Results (${matchedPersonnel.length})',
                                          style: TextStyle(
                                            color: goldAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...matchedPersonnel.map((person) {
                                    final armyNo = person['armyNo'] ?? '';
                                    final rank = person['rank'] ?? '';
                                    final name = person['name'] ?? '';
                                    final status = manager.getStatus(armyNo);
                                    final isLeave = status.category == 'Leave';
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PersonnelIdCardScreen(
                                              person: person,
                                              isDark: isDark,
                                              textThemeColor: textThemeColor,
                                              silverText: silverText,
                                              goldAccent: goldAccent,
                                              valueGreenColor: valueGreenColor,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF0C5A32).withValues(alpha: 0.10)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark
                                                ? goldAccent.withValues(alpha: 0.25)
                                                : const Color(0xFF0C5A32).withValues(alpha: 0.18),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isDark
                                                  ? Colors.black.withValues(alpha: 0.08)
                                                  : const Color(0xFF0C5A32).withValues(alpha: 0.04),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: isDark
                                                  ? goldAccent.withValues(alpha: 0.15)
                                                  : const Color(0xFF0C5A32).withValues(alpha: 0.10),
                                              child: Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                style: TextStyle(
                                                  color: goldAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$rank $name',
                                                    style: TextStyle(
                                                      color: textThemeColor,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Army No: $armyNo',
                                                    style: TextStyle(
                                                      color: silverText,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isLeave
                                                    ? Colors.redAccent.withValues(alpha: 0.12)
                                                    : const Color(0xFF388E3C).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status.category,
                                                style: TextStyle(
                                                  color: isLeave ? Colors.redAccent : Colors.green,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(Icons.chevron_right_rounded,
                                                color: silverText, size: 18),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 10),
                                ];
                              })(),

                              // DETAILED STRENGTH BREAKDOWNS SECTION
                              if (_searchQuery.isEmpty) ...[
                                ...manager.categoryHierarchy.entries
                                    .where((entry) => entry.value != null)
                                    .map((entry) {
                                      final categoryName = entry.key;
                                      final categoryData = entry.value;
                                      final count = manager.getCountForCategory(
                                        categoryName,
                                      );

                                      List<Widget> columns = [];
                                      if (categoryData is List) {
                                        final List<String> list =
                                            List<String>.from(categoryData);
                                        final mid = (list.length / 2).ceil();
                                        final leftItems = list
                                            .take(mid)
                                            .toList();
                                        final rightItems = list
                                            .skip(mid)
                                            .toList();

                                        columns = [
                                          _buildDetailColumn(
                                            isDark: isDark,
                                            textThemeColor: textThemeColor,
                                            goldAccent: goldAccent,
                                            silverText: silverText,
                                            valueGreenColor: valueGreenColor,
                                            mainCategory: categoryName,
                                            context: context,
                                            items: leftItems
                                                .map(
                                                  (sub) => {
                                                    'name': sub,
                                                    'val':
                                                        '${manager.getCountForSubcategory(categoryName, sub)}',
                                                  },
                                                )
                                                .toList(),
                                          ),
                                          if (rightItems.isNotEmpty)
                                            _buildDetailColumn(
                                              isDark: isDark,
                                              textThemeColor: textThemeColor,
                                              goldAccent: goldAccent,
                                              silverText: silverText,
                                              valueGreenColor: valueGreenColor,
                                              mainCategory: categoryName,
                                              context: context,
                                              items: rightItems
                                                  .map(
                                                    (sub) => {
                                                      'name': sub,
                                                      'val':
                                                          '${manager.getCountForSubcategory(categoryName, sub)}',
                                                    },
                                                  )
                                                  .toList(),
                                            ),
                                        ];
                                      } else if (categoryData is Map) {
                                        final map = Map<String, dynamic>.from(
                                          categoryData,
                                        );
                                        columns = map.entries.map((subEntry) {
                                          final subName = subEntry.key;
                                          final List<String> subSubList =
                                              List<String>.from(
                                                subEntry.value as List,
                                              );

                                          return _buildDetailColumn(
                                            header:
                                                '$subName - ${manager.getCountForSubcategory(categoryName, subName)}',
                                            isDark: isDark,
                                            textThemeColor: textThemeColor,
                                            goldAccent: goldAccent,
                                            silverText: silverText,
                                            valueGreenColor: valueGreenColor,
                                            mainCategory: categoryName,
                                            subCategory: subName,
                                            context: context,
                                            items: [],
                                          );
                                        }).toList();
                                      }

                                      return Column(
                                        children: [
                                          _buildDetailsPanel(
                                            title: '$categoryName - $count',
                                            isDark: isDark,
                                            goldAccent: goldAccent,
                                            silverText: silverText,
                                            textThemeColor: textThemeColor,
                                            bulletColor: valueGreenColor,
                                            columns: columns,
                                          ),
                                          const SizedBox(height: 15),
                                        ],
                                      );
                                    }),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _selectedTabIndex == 1
                ? _buildAnalysisTab(
                    context,
                    isDark,
                    textThemeColor,
                    silverText,
                    goldAccent,
                    valueGreenColor,
                  )
                : _selectedTabIndex == 2
                ? _buildNominalRollTab(
                    context,
                    isDark,
                    textThemeColor,
                    silverText,
                    goldAccent,
                    valueGreenColor,
                  )
                : _selectedTabIndex == 3
                ? _buildAttendanceFilterTab(
                    context,
                    isDark,
                    textThemeColor,
                    silverText,
                    goldAccent,
                    valueGreenColor,
                  )
                : _buildSettingsTab(
                    context,
                    isDark,
                    textThemeColor,
                    silverText,
                    goldAccent,
                    valueGreenColor,
                  ),
          ),

          // 4. FLOATING GLOWING SEARCH BAR
          if (_selectedTabIndex == 0)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF0C5A32).withValues(alpha: 0.25)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.08),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _searchController,
                  style: TextStyle(color: textThemeColor, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      color: goldAccent.withValues(alpha: 0.8),
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: silverText,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    hintText: 'Search Personnel...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0A2214).withValues(alpha: 0.85)
                        : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? goldAccent.withValues(alpha: 0.35)
                            : const Color(0xFF0C5A32).withValues(alpha: 0.25),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: goldAccent, width: 1.2),
                    ),
                  ),
                ),
              ),
            ),
          // MAIN DYNAMIC FAB SPEED DIAL
          if (_selectedTabIndex == 0 && _canAccessFABs) ...[
            // 1. ADD SUB-FAB (PLUS)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              bottom: _isFabMenuOpen ? 155 : 95,
              right: 23,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isFabMenuOpen,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0xFFCD9B2D).withValues(alpha: 0.25)
                              : const Color(0xFF0C5A32).withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        _dashVM.setFabMenuOpen(false);
                        _showAddCategoryDialog(
                          context,
                          isDark,
                          textThemeColor,
                          silverText,
                          goldAccent,
                          valueGreenColor,
                        );
                      },
                      mini: true,
                      backgroundColor: goldAccent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      child: const Icon(Icons.add_rounded, size: 20),
                    ),
                  ),
                ),
              ),
            ),

            // 2. EDIT SUB-FAB (PENCIL)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              bottom: _isFabMenuOpen ? 205 : 95,
              right: 23,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isFabMenuOpen,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0xFFCD9B2D).withValues(alpha: 0.25)
                              : const Color(0xFF0C5A32).withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        _dashVM.setFabMenuOpen(false);
                        _showManageCategoryDialog(
                          context,
                          isDark,
                          textThemeColor,
                          silverText,
                          goldAccent,
                          valueGreenColor,
                        );
                      },
                      mini: true,
                      backgroundColor: goldAccent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      child: const Icon(Icons.edit_rounded, size: 18),
                    ),
                  ),
                ),
              ),
            ),

            // 3. DELETE SUB-FAB (TRASH)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              bottom: _isFabMenuOpen ? 255 : 95,
              right: 23,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isFabMenuOpen,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0xFFCD9B2D).withValues(alpha: 0.25)
                              : const Color(0xFF0C5A32).withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        _dashVM.setFabMenuOpen(false);
                        _showDeleteCategoryDialog(
                          context,
                          isDark,
                          textThemeColor,
                          silverText,
                          goldAccent,
                          valueGreenColor,
                        );
                      },
                      mini: true,
                      backgroundColor: goldAccent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      child: const Icon(Icons.delete_rounded, size: 18),
                    ),
                  ),
                ),
              ),
            ),

            // 4. MAIN TRIGGER FAB (MENU / CLOSE)
            Positioned(
              bottom: 95,
              right: 20,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFFCD9B2D).withValues(alpha: 0.35)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: () {
                    _dashVM.setFabMenuOpen(!_dashVM.isFabMenuOpen);
                  },
                  backgroundColor: goldAccent,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: _isFabMenuOpen ? 0.25 : 0.0,
                    child: Icon(
                      _isFabMenuOpen ? Icons.close_rounded : Icons.menu_rounded,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
          // NOMINAL ROLL FAB SPEED DIAL
          if (_selectedTabIndex == 2 && MockDataManager().role == 'Administrator') ...[
            // 1. ADD PERSON SUB-FAB (PLUS)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              bottom: _isRollFabMenuOpen ? 155 : 95,
              right: 23,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isRollFabMenuOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isRollFabMenuOpen,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0xFFCD9B2D).withValues(alpha: 0.25)
                              : const Color(0xFF0C5A32).withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        _dashVM.setRollFabMenuOpen(false);
                        _showPersonFormDialog(
                          context,
                          isDark: isDark,
                          textThemeColor: textThemeColor,
                          silverText: silverText,
                          goldAccent: goldAccent,
                          valueGreenColor: valueGreenColor,
                        );
                      },
                      mini: true,
                      backgroundColor: goldAccent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      child: const Icon(Icons.person_add_rounded, size: 18),
                    ),
                  ),
                ),
              ),
            ),

            // 2. TOGGLE EDIT MODE SUB-FAB (PENCIL)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              bottom: _isRollFabMenuOpen ? 205 : 95,
              right: 23,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isRollFabMenuOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isRollFabMenuOpen,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _isRollEditMode
                              ? Colors.redAccent.withValues(alpha: 0.3)
                              : (isDark
                                    ? const Color(
                                        0xFFCD9B2D,
                                      ).withValues(alpha: 0.25)
                                    : const Color(
                                        0xFF0C5A32,
                                      ).withValues(alpha: 0.2)),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        _dashVM.setRollFabMenuOpen(false);
                        _dashVM.setRollEditMode(!_dashVM.isRollEditMode);
                        _dashVM.setRollDeleteMode(false);
                      },
                      mini: true,
                      backgroundColor: _isRollEditMode
                          ? Colors.redAccent
                          : goldAccent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      child: Icon(
                        _isRollEditMode
                            ? Icons.edit_off_rounded
                            : Icons.edit_rounded,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. TOGGLE DELETE MODE SUB-FAB (TRASH)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              bottom: _isRollFabMenuOpen ? 255 : 95,
              right: 23,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isRollFabMenuOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isRollFabMenuOpen,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _isRollDeleteMode
                              ? Colors.redAccent.withValues(alpha: 0.3)
                              : (isDark
                                    ? const Color(
                                        0xFFCD9B2D,
                                      ).withValues(alpha: 0.25)
                                    : const Color(
                                        0xFF0C5A32,
                                      ).withValues(alpha: 0.2)),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        _dashVM.setRollFabMenuOpen(false);
                        _dashVM.setRollDeleteMode(!_dashVM.isRollDeleteMode);
                        _dashVM.setRollEditMode(false);
                      },
                      mini: true,
                      backgroundColor: _isRollDeleteMode
                          ? Colors.redAccent
                          : goldAccent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      child: Icon(
                        _isRollDeleteMode
                            ? Icons.delete_forever_rounded
                            : Icons.delete_rounded,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4. MAIN TRIGGER FAB (MENU / CLOSE)
            Positioned(
              bottom: 95,
              right: 20,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFFCD9B2D).withValues(alpha: 0.35)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: () {
                    _dashVM.setRollFabMenuOpen(!_dashVM.isRollFabMenuOpen);
                  },
                  backgroundColor: goldAccent,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: _isRollFabMenuOpen ? 0.25 : 0.0,
                    child: Icon(
                      _isRollFabMenuOpen
                          ? Icons.close_rounded
                          : Icons.menu_rounded,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF03140A).withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.98),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFFCD9B2D).withValues(alpha: 0.25)
                  : const Color(0xFF0C5A32).withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              currentIndex: _selectedTabIndex,
              onTap: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: isDark ? goldAccent : const Color(0xFF0C5A32),
              unselectedItemColor: isDark
                  ? silverText.withValues(alpha: 0.5)
                  : const Color(0xFF0C5A32).withValues(alpha: 0.55),
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_rounded),
                  label: 'Analysis',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_rounded),
                  label: 'Nominal Roll',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.filter_list_rounded),
                  label: 'Filter',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDatePickerTheme(BuildContext context, Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFCD9B2D),
          onPrimary: Colors.black,
          surface: Color(0xFF0A2214),
          onSurface: Colors.white,
        ),
      ),
      child: child,
    );
  }

  Widget _buildFilterLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, left: 2.0),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF8B9B90),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFilterDateDisplay(String text, bool isDark, Color goldAccent, Color textThemeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            text,
            style: TextStyle(color: textThemeColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Icon(Icons.calendar_month_rounded, color: goldAccent, size: 16),
        ],
      ),
    );
  }

  Widget _buildAttendanceFilterTab(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final manager = context.watch<PersonnelDataManager>();
    final seenCategories = <String>{'All'};
    final categoryOptions = ['All'];
    for (var key in manager.categoryHierarchy.keys) {
      if (seenCategories.add(key)) {
        categoryOptions.add(key);
      }
    }

    // Ensure filter category is valid
    if (!categoryOptions.contains(_filterCategory)) {
      _filterCategory = 'All';
    }
    final currentSubcategories = _filterCategory == 'All' 
        ? <String>[] 
        : (manager.categoryHierarchy[_filterCategory] is List 
            ? List<String>.from(manager.categoryHierarchy[_filterCategory] as List)
            : (manager.categoryHierarchy[_filterCategory] is Map
                ? (manager.categoryHierarchy[_filterCategory] as Map).keys.cast<String>().toList()
                : <String>[]));

    final filteredPersonnel = nominalRollList.where((person) {
      final armyNo = person['armyNo'] ?? '';
      final status = manager.getStatus(armyNo);

      if (_filterCategory != 'All' && status.category != _filterCategory) {
        return false;
      }

      if (_filterSelectedSubcategories.isNotEmpty && 
          (status.subcategory == null || !_filterSelectedSubcategories.contains(status.subcategory))) {
        return false;
      }

      if (_filterStartDate != null) {
        if (!DateUtils.isSameDay(status.startDate, _filterStartDate)) {
          return false;
        }
      }

      if (_filterEndDate != null) {
        if (status.endDate == null || !DateUtils.isSameDay(status.endDate, _filterEndDate)) {
          return false;
        }
      }

      if (_filterDestinationQuery.isNotEmpty) {
        final homeCity = _getCity(person).toLowerCase();
        final matchesHomeCity = homeCity.contains(_filterDestinationQuery);
        final matchesStatus = status.matchesLocationQuery(_filterDestinationQuery);
        if (!matchesHomeCity && !matchesStatus) {
          return false;
        }
      }

      return true;
    }).toList();

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 80.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C5A32).withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? goldAccent.withValues(alpha: 0.25) : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.15) : const Color(0xFF0C5A32).withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTENDANCE FILTER CRITERIA',
                  style: TextStyle(
                    color: goldAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const Divider(height: 20, thickness: 0.5),
                 Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterLabel('Category'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: goldAccent.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: categoryOptions.contains(_filterCategory) ? _filterCategory : categoryOptions.first,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF0A2214) : Colors.white,
                                icon: Icon(Icons.arrow_drop_down, color: goldAccent),
                                style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _filterCategory = val;
                                      _filterSelectedSubcategories.clear();
                                      if (_filterCategory != 'Leave') {
                                        _filterDestinationController.clear();
                                        _filterDestinationQuery = '';
                                      }
                                    });
                                  }
                                },
                                items: categoryOptions.map((cat) {
                                  return DropdownMenuItem<String>(
                                    value: cat,
                                    child: Text(cat),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_filterCategory == 'Leave') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFilterLabel('Destination / Place'),
                            TextFormField(
                              controller: _filterDestinationController,
                              style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'Search location...',
                                hintStyle: TextStyle(color: silverText.withValues(alpha: 0.5), fontSize: 12),
                                prefixIcon: Icon(Icons.location_on_rounded, color: goldAccent, size: 16),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: goldAccent.withValues(alpha: 0.3), width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: goldAccent, width: 1.2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (currentSubcategories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildFilterLabel('Subcategories Filter'),
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: currentSubcategories.length,
                      itemBuilder: (context, idx) {
                        final sub = currentSubcategories[idx];
                        final isSelected = _filterSelectedSubcategories.contains(sub);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(
                              sub,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? (isDark ? Colors.black : Colors.white) : textThemeColor,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _filterSelectedSubcategories.add(sub);
                                } else {
                                  _filterSelectedSubcategories.remove(sub);
                                }
                              });
                            },
                            backgroundColor: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE),
                            selectedColor: goldAccent,
                            checkmarkColor: isDark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? goldAccent : goldAccent.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterLabel('Start Date'),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _filterStartDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                builder: (ctx, child) => _buildDatePickerTheme(ctx, child!),
                              );
                              if (picked != null) {
                                setState(() {
                                  _filterStartDate = picked;
                                });
                              }
                            },
                            child: _buildFilterDateDisplay(
                              _filterStartDate != null 
                                  ? '${_filterStartDate!.day}/${_filterStartDate!.month}/${_filterStartDate!.year}'
                                  : 'Select Start Date',
                              isDark,
                              goldAccent,
                              textThemeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterLabel('End Date'),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _filterEndDate ?? DateTime.now(),
                                firstDate: _filterStartDate ?? DateTime(2020),
                                lastDate: DateTime(2030),
                                builder: (ctx, child) => _buildDatePickerTheme(ctx, child!),
                              );
                              if (picked != null) {
                                setState(() {
                                  _filterEndDate = picked;
                                });
                              }
                            },
                            child: _buildFilterDateDisplay(
                              _filterEndDate != null 
                                  ? '${_filterEndDate!.day}/${_filterEndDate!.month}/${_filterEndDate!.year}'
                                  : 'Select End Date',
                              isDark,
                              goldAccent,
                              textThemeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_filterStartDate != null || _filterEndDate != null || _filterSelectedSubcategories.isNotEmpty || _filterDestinationQuery.isNotEmpty || _filterCategory != 'Leave') ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: goldAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () {
                        setState(() {
                          _filterCategory = 'Leave';
                          _filterSelectedSubcategories.clear();
                          _filterStartDate = null;
                          _filterEndDate = null;
                          _filterDestinationController.clear();
                          _filterDestinationQuery = '';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FILTERED RESULTS',
                style: TextStyle(
                  color: silverText,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${filteredPersonnel.length} PERSONNEL FOUND',
                style: TextStyle(
                  color: valueGreenColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'serif',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filteredPersonnel.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_list_off_rounded, size: 48, color: silverText.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),
                      Text(
                        'No personnel matches current filters',
                        style: TextStyle(color: silverText.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  itemCount: filteredPersonnel.length,
                  itemBuilder: (context, index) {
                    final person = filteredPersonnel[index];
                    final armyNo = person['armyNo'] ?? '';
                    final status = manager.getStatus(armyNo);
                    final rank = person['rank'] ?? '';
                    final name = person['name'] ?? '';
                    final isLeave = status.category == 'Leave';
                    
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PersonnelIdCardScreen(
                              person: person,
                              isDark: isDark,
                              textThemeColor: textThemeColor,
                              silverText: silverText,
                              goldAccent: goldAccent,
                              valueGreenColor: valueGreenColor,
                            ),
                          ),
                        );
                      },
      child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isDark ? const Color(0xFF0C5A32).withValues(alpha: 0.08) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? goldAccent.withValues(alpha: 0.2) : const Color(0xFF0C5A32).withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$rank $name',
                                    style: TextStyle(
                                      color: textThemeColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isLeave 
                                        ? const Color(0xFFD32F2F).withValues(alpha: 0.15)
                                        : const Color(0xFF388E3C).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.displayPath,
                                    style: TextStyle(
                                      color: isLeave ? Colors.redAccent : Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month_rounded, color: goldAccent, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${status.startDate.day}/${status.startDate.month}/${status.startDate.year}${status.endDate != null 
                                              ? ' to ${status.endDate!.day}/${status.endDate!.month}/${status.endDate!.year}'
                                              : ' (Infinite)'}',
                                      style: TextStyle(color: silverText, fontSize: 12),
                                    ),
                                  ],
                                ),
                                if (isLeave)
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_rounded, color: goldAccent, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        (status.destination != null && status.destination!.isNotEmpty)
                                            ? status.destination!
                                            : _getCity(person),
                                        style: TextStyle(color: textThemeColor, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEditTab(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final manager = PersonnelDataManager();
    final List<Map<String, String>> filteredList;

    if (_editSearchQuery.isNotEmpty) {
      filteredList = nominalRollList.where((person) {
        final name = (person['name'] ?? '').toLowerCase();
        final armyNo = (person['armyNo'] ?? '').toLowerCase();
        final rank = (person['rank'] ?? '').toLowerCase();
        return name.contains(_editSearchQuery) ||
            armyNo.contains(_editSearchQuery) ||
            rank.contains(_editSearchQuery);
      }).toList();
    } else {
      filteredList = [];
    }

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 80.0),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.15)
                      : const Color(0xFF0C5A32).withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: TextFormField(
              controller: _editSearchController,
              style: TextStyle(color: textThemeColor, fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: goldAccent, size: 20),
                suffixIcon: _editSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: silverText, size: 18),
                        onPressed: () {
                          _editSearchController.clear();
                        },
                      )
                    : null,
                hintText: 'Search person to edit assignment...',
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : const Color(0xFF0C5A32).withValues(alpha: 0.45),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0C5A32).withValues(alpha: 0.05)
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? goldAccent.withValues(alpha: 0.25)
                        : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: goldAccent, width: 1.2),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: _editSearchQuery.isNotEmpty
              ? filteredList.isEmpty
                    ? Center(
                        child: Text(
                          'No Personnel Found',
                          style: TextStyle(color: silverText, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          return _buildEditPersonnelRow(
                            filteredList[index],
                            isDark,
                            textThemeColor,
                            silverText,
                            goldAccent,
                            valueGreenColor,
                          );
                        },
                      )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 100,
                  ),
                  itemCount: manager.categoryHierarchy.keys.length,
                  itemBuilder: (context, index) {
                    final categoryName = manager.categoryHierarchy.keys
                        .elementAt(index);
                    return _buildCategoryTreeTile(
                      categoryName,
                      isDark,
                      textThemeColor,
                      silverText,
                      goldAccent,
                      valueGreenColor,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryTreeTile(
    String categoryName,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final manager = PersonnelDataManager();
    final isExpanded = _expandedEditCategories.contains(categoryName);
    final categoryData = manager.categoryHierarchy[categoryName];
    final count = manager.getCountForCategory(categoryName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C5A32).withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? goldAccent.withValues(alpha: 0.25)
              : const Color(0xFF0C5A32).withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              categoryName,
              style: TextStyle(
                color: textThemeColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: valueGreenColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: valueGreenColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: goldAccent,
                ),
              ],
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedEditCategories.remove(categoryName);
                } else {
                  _expandedEditCategories.add(categoryName);
                }
              });
            },
          ),
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 0.5),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildCategoryChildren(
                categoryName,
                categoryData,
                isDark,
                textThemeColor,
                silverText,
                goldAccent,
                valueGreenColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChildren(
    String categoryName,
    dynamic categoryData,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final manager = PersonnelDataManager();

    if (categoryData == null) {
      // Leaf node directly: show personnel list
      final people = manager.getPeopleInNode(category: categoryName);
      return _buildEditPersonnelList(
        people,
        isDark,
        textThemeColor,
        silverText,
        goldAccent,
        valueGreenColor,
      );
    }

    if (categoryData is List<String>) {
      // Subcategories as list
      return Column(
        children: categoryData.map((subName) {
          final subPath = '$categoryName -> $subName';
          final isSubExpanded = _expandedEditSubcategories.contains(subPath);
          final subCount = manager.getCountForSubcategory(
            categoryName,
            subName,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF03140A).withValues(alpha: 0.5)
                  : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? goldAccent.withValues(alpha: 0.15)
                    : const Color(0xFF0C5A32).withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  title: Text(
                    subName,
                    style: TextStyle(
                      color: textThemeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$subCount',
                        style: TextStyle(
                          color: goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSubExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: goldAccent,
                        size: 18,
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      if (isSubExpanded) {
                        _expandedEditSubcategories.remove(subPath);
                      } else {
                        _expandedEditSubcategories.add(subPath);
                      }
                    });
                  },
                ),
                if (isSubExpanded) ...[
                  const Divider(height: 1, thickness: 0.5),
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: _buildEditPersonnelList(
                      manager.getPeopleInNode(
                        category: categoryName,
                        subcategory: subName,
                      ),
                      isDark,
                      textThemeColor,
                      silverText,
                      goldAccent,
                      valueGreenColor,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    if (categoryData is Map<String, List<String>>) {
      // Subcategories with Sub-subcategories
      return Column(
        children: categoryData.keys.map((subName) {
          final subPath = '$categoryName -> $subName';
          final isSubExpanded = _expandedEditSubcategories.contains(subPath);
          final subCount = manager.getCountForSubcategory(
            categoryName,
            subName,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF03140A).withValues(alpha: 0.5)
                  : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? goldAccent.withValues(alpha: 0.15)
                    : const Color(0xFF0C5A32).withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  title: Text(
                    subName,
                    style: TextStyle(
                      color: textThemeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$subCount',
                        style: TextStyle(
                          color: goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSubExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: goldAccent,
                        size: 18,
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      if (isSubExpanded) {
                        _expandedEditSubcategories.remove(subPath);
                      } else {
                        _expandedEditSubcategories.add(subPath);
                      }
                    });
                  },
                ),
                if (isSubExpanded) ...[
                  const Divider(height: 1, thickness: 0.5),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _buildEditPersonnelList(
                      manager.getPeopleInNode(
                        category: categoryName,
                        subcategory: subName,
                      ),
                      isDark,
                      textThemeColor,
                      silverText,
                      goldAccent,
                      valueGreenColor,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEditPersonnelList(
    List<Map<String, String>> people,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    if (people.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Text(
            'No personnel assigned.',
            style: TextStyle(
              color: silverText.withValues(alpha: 0.7),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      children: people.map((person) {
        return _buildEditPersonnelRow(
          person,
          isDark,
          textThemeColor,
          silverText,
          goldAccent,
          valueGreenColor,
        );
      }).toList(),
    );
  }

  Widget _buildEditPersonnelRow(
    Map<String, String> person,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final rank = person['rank'] ?? '';
    final name = person['name'] ?? '';
    final armyNo = person['armyNo'] ?? '';
    final status = PersonnelDataManager().getStatus(armyNo);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C5A32).withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? goldAccent.withValues(alpha: 0.15)
              : const Color(0xFF0C5A32).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Rank Initials Badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: goldAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: goldAccent.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                rank,
                style: TextStyle(
                  color: goldAccent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: textThemeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$armyNo  •  ${status.displayPath}',
                  style: TextStyle(color: silverText, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_note_rounded, color: goldAccent, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditAssignmentScreen(
                    person: person,
                    isDark: isDark,
                    textThemeColor: textThemeColor,
                    silverText: silverText,
                    goldAccent: goldAccent,
                    valueGreenColor: valueGreenColor,
                    onSaved: () {
                      setState(() {});
                    },
                  ),
                ),
              ).then((_) {
                setState(() {});
              });
            },
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    String title,
    String initialValue,
    Function(String) onRename,
    bool isDark,
    Color goldAccent,
    Color textThemeColor,
    Color silverText,
  ) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: goldAccent.withValues(alpha: 0.3)),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: goldAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            style: TextStyle(color: textThemeColor, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: goldAccent.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: goldAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(color: silverText, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  onRename(newName);
                }
                Navigator.pop(context);
              },
              child: Text(
                'RENAME',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    String itemName,
    VoidCallback onDelete,
    bool isDark,
    Color goldAccent,
    Color silverText,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          title: const Text(
            'CONFIRM DELETE',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$itemName"? Assigned personnel will be updated.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 12,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(color: silverText, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: () {
                onDelete();
                Navigator.pop(context);
              },
              child: const Text(
                'DELETE',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showManageCategoryDialog(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final manager = PersonnelDataManager();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: goldAccent.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              title: Text(
                'EDIT CATEGORY NAMES',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.7,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: manager.categoryHierarchy.keys.map((category) {
                    final catData = manager.categoryHierarchy[category];

                    return Card(
                      color: isDark
                          ? const Color(0xFF03140A)
                          : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: goldAccent.withValues(alpha: 0.15),
                        ),
                      ),
                      child: ExpansionTile(
                        iconColor: goldAccent,
                        collapsedIconColor: silverText,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: textThemeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit_note_rounded,
                                color: goldAccent,
                                size: 18,
                              ),
                              onPressed: () {
                                _showRenameDialog(
                                  context,
                                  'RENAME CATEGORY',
                                  category,
                                  (newName) {
                                    setDialogState(() {
                                      manager.renameCategory(category, newName);
                                    });
                                    setState(() {});
                                  },
                                  isDark,
                                  goldAccent,
                                  textThemeColor,
                                  silverText,
                                );
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                        children: [
                          if (catData == null)
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                'No subcategories assigned.',
                                style: TextStyle(
                                  color: silverText.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else if (catData is List)
                            ...catData.map((sub) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      color: Colors.grey,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sub,
                                        style: TextStyle(
                                          color: textThemeColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_note_rounded,
                                        color: goldAccent,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _showRenameDialog(
                                          context,
                                          'RENAME SUBCATEGORY',
                                          sub,
                                          (newName) {
                                            setDialogState(() {
                                              manager.renameSubcategory(
                                                category,
                                                sub,
                                                newName,
                                              );
                                            });
                                            setState(() {});
                                          },
                                          isDark,
                                          goldAccent,
                                          textThemeColor,
                                          silverText,
                                        );
                                      },
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                              );
                            })
                          else if (catData is Map)
                            ...catData.entries.map((subEntry) {
                              final subName = subEntry.key;
                              final subSubList = List<String>.from(
                                subEntry.value as List,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 8,
                                ),
                                child: ExpansionTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          subName,
                                          style: TextStyle(
                                            color: textThemeColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_note_rounded,
                                          color: goldAccent,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          _showRenameDialog(
                                            context,
                                            'RENAME SUBCATEGORY',
                                            subName,
                                            (newName) {
                                              setDialogState(() {
                                                manager.renameSubcategory(
                                                  category,
                                                  subName,
                                                  newName,
                                                );
                                              });
                                              setState(() {});
                                            },
                                            isDark,
                                            goldAccent,
                                            textThemeColor,
                                            silverText,
                                          );
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    if (subSubList.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          'No sub-subcategories details assigned.',
                                          style: TextStyle(
                                            color: silverText.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      )
                                    else
                                      ...subSubList.map((subSub) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons
                                                    .subdirectory_arrow_right_rounded,
                                                color: Colors.grey,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  subSub,
                                                  style: TextStyle(
                                                    color: textThemeColor,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit_note_rounded,
                                                  color: goldAccent,
                                                  size: 14,
                                                ),
                                                onPressed: () {
                                                  _showRenameDialog(
                                                    context,
                                                    'RENAME DETAIL',
                                                    subSub,
                                                    (newName) {
                                                      setDialogState(() {
                                                        manager
                                                            .renameSubcategory( // 
                                                              category,
                                                              subName,
                                                              subSub,
                                                              newName,
                                                            );
                                                      });
                                                      setState(() {});
                                                    },
                                                    isDark,
                                                    goldAccent,
                                                    textThemeColor,
                                                    silverText,
                                                  );
                                                },
                                                constraints:
                                                    const BoxConstraints(),
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteCategoryDialog(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final manager = PersonnelDataManager();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              title: const Text(
                'DELETE CATEGORIES',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.7,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: manager.categoryHierarchy.keys.map((category) {
                    final catData = manager.categoryHierarchy[category];

                    return Card(
                      color: isDark
                          ? const Color(0xFF03140A)
                          : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                        ),
                      ),
                      child: ExpansionTile(
                        iconColor: Colors.redAccent,
                        collapsedIconColor: silverText,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: textThemeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              onPressed: () {
                                _showDeleteConfirmDialog(
                                  context,
                                  category,
                                  () {
                                    setDialogState(() {
                                      manager.deleteCategory(category);
                                    });
                                    setState(() {});
                                  },
                                  isDark,
                                  goldAccent,
                                  silverText,
                                );
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                        children: [
                          if (catData == null)
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                'No subcategories assigned.',
                                style: TextStyle(
                                  color: silverText.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else if (catData is List)
                            ...catData.map((sub) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      color: Colors.grey,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sub,
                                        style: TextStyle(
                                          color: textThemeColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _showDeleteConfirmDialog(
                                          context,
                                          sub,
                                          () {
                                            setDialogState(() {
                                              manager.deleteSubcategory(
                                                category,
                                                sub,
                                              );
                                            });
                                            setState(() {});
                                          },
                                          isDark,
                                          goldAccent,
                                          silverText,
                                        );
                                      },
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                              );
                            })
                          else if (catData is Map)
                            ...catData.entries.map((subEntry) {
                              final subName = subEntry.key;
                              final subSubList = List<String>.from(
                                subEntry.value as List,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 8,
                                ),
                                child: ExpansionTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          subName,
                                          style: TextStyle(
                                            color: textThemeColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          _showDeleteConfirmDialog(
                                            context,
                                            subName,
                                            () {
                                              setDialogState(() {
                                                manager.deleteSubcategory(
                                                  category,
                                                  subName,
                                                );
                                              });
                                              setState(() {});
                                            },
                                            isDark,
                                            goldAccent,
                                            silverText,
                                          );
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    if (subSubList.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          'No sub-subcategories details assigned.',
                                          style: TextStyle(
                                            color: silverText.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      )
                                    else
                                      ...subSubList.map((subSub) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons
                                                    .subdirectory_arrow_right_rounded,
                                                color: Colors.grey,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  subSub,
                                                  style: TextStyle(
                                                    color: textThemeColor,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.redAccent,
                                                  size: 14,
                                                ),
                                                onPressed: () {
                                                  _showDeleteConfirmDialog(
                                                    context,
                                                    subSub,
                                                    () {
                                                      setDialogState(() {
                                                        manager
                                                            .deleteSubcategory( // 
                                                              category,
                                                              subName,
                                                              subSub,
                                                            );
                                                      });
                                                      setState(() {});
                                                    },
                                                    isDark,
                                                    goldAccent,
                                                    silverText,
                                                  );
                                                },
                                                constraints:
                                                    const BoxConstraints(),
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: silverText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final manager = PersonnelDataManager();
    String addType = 'Main Category';
    final nameController = TextEditingController();
    String? selectedMainCat;
    String? selectedSubCat;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final mainCategories = manager.categoryHierarchy.keys.toList();
            List<String> subCategories = [];
            if (selectedMainCat != null) {
              final catData = manager.categoryHierarchy[selectedMainCat];
              if (catData is List) {
                subCategories = List<String>.from(catData);
              } else if (catData is Map) {
                subCategories = List<String>.from(catData.keys);
              }
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: goldAccent.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              title: Text(
                'ADD NEW CATEGORY',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADDITION TYPE',
                      style: TextStyle(
                        color: silverText,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF03140A)
                            : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: goldAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: addType,
                          dropdownColor: isDark
                              ? const Color(0xFF0A2214)
                              : Colors.white,
                          style: TextStyle(
                            color: textThemeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'Main Category',
                              child: Text('Add Main Category'),
                            ),
                            DropdownMenuItem(
                              value: 'Subcategory',
                              child: Text('Add Subcategory'),
                            ),
                            DropdownMenuItem(
                              value: 'Sub-subcategory',
                              child: Text('Add Sub-subcategory Detail'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                addType = val;
                                nameController.clear();
                                selectedMainCat = null;
                                selectedSubCat = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (addType == 'Subcategory' ||
                        addType == 'Sub-subcategory') ...[
                      Text(
                        'SELECT MAIN CATEGORY',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF03140A)
                              : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedMainCat,
                            hint: Text(
                              'Choose category',
                              style: TextStyle(color: silverText, fontSize: 11),
                            ),
                            dropdownColor: isDark
                                ? const Color(0xFF0A2214)
                                : Colors.white,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            isExpanded: true,
                            items: mainCategories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedMainCat = val;
                                selectedSubCat = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (addType == 'Sub-subcategory') ...[
                      Text(
                        'SELECT SUBCATEGORY',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF03140A)
                              : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSubCat,
                            hint: Text(
                              'Choose subcategory',
                              style: TextStyle(color: silverText, fontSize: 11),
                            ),
                            dropdownColor: isDark
                                ? const Color(0xFF0A2214)
                                : Colors.white,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            isExpanded: true,
                            items: subCategories.map((sub) {
                              return DropdownMenuItem(
                                value: sub,
                                child: Text(sub),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedSubCat = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Text(
                      addType == 'Main Category'
                          ? 'MAIN CATEGORY NAME'
                          : addType == 'Subcategory'
                          ? 'SUBCATEGORY NAME'
                          : 'SUB-SUBCATEGORY NAME',
                      style: TextStyle(
                        color: silverText,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textThemeColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter name...',
                        hintStyle: TextStyle(
                          color: silverText.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF03140A)
                            : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: goldAccent.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: goldAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: silverText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    if (addType == 'Main Category') {
                      manager.addMainCategory(name);
                    } else if (addType == 'Subcategory') {
                      if (selectedMainCat == null) return;
                      manager.addSubcategory(selectedMainCat!, name);
                    } else if (addType == 'Sub-subcategory') {
                      if (selectedMainCat == null || selectedSubCat == null) {
                        return;
                      }
                      manager.addSubcategory( // 
                        selectedMainCat!,
                        selectedSubCat!,
                        name,
                      );
                    }

                    setState(() {});
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Successfully added $name to $addType hierarchy!',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFF0C5A32),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C5A32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'ADD',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeletePersonConfirmDialog(
    BuildContext context,
    Map<String, String> person,
    bool isDark,
    Color goldAccent,
    Color silverText,
  ) {
    final name = person['name'] ?? '';
    final armyNo = person['armyNo'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          title: const Text(
            'CONFIRM DELETE PERSONNEL',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete $name ($armyNo) from Nominal Roll?',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 12,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(color: silverText, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: () async {
                await PersonnelDataManager().removePerson(armyNo);
                if (mounted) {
                  setState(() {});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully deleted $name!'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text(
                'DELETE',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showManageAdminsDialog(
    BuildContext pageContext,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    showDialog(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: MockDataManager().getCommandGroup(),
              builder: (context, snapshot) {
                final group = snapshot.data ?? [];

                return AlertDialog(
                  backgroundColor: isDark
                      ? const Color(0xFF0A2214)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: goldAccent.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  title: Text(
                    'MANAGE COMMAND GROUP (12 MEMBERS)',
                    style: TextStyle(
                      color: goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.95,
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1 SUPER ADMIN • 4 ADMINS • 7 USERS',
                          style: TextStyle(
                            color: silverText,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: group.length,
                            itemBuilder: (context, index) {
                              final slot = group[index];
                              final slotId = slot['slotId'] as int;
                              final slotRole = slot['role'] as String;
                              final armyNo = slot['armyNo'] as String?;
                              final username =
                                  slot['username'] as String? ?? '';

                              String roleLabel = 'USER';
                              if (slotRole == 'superadmin') {
                                roleLabel = 'SUPER ADMIN';
                              }
                              if (slotRole == 'admin') roleLabel = 'ADMIN';

                              String details = 'Empty Slot';
                              if (armyNo != null) {
                                final person = nominalRollList.firstWhere(
                                  (p) =>
                                      (p['armyNo'] ?? '').toLowerCase() ==
                                      armyNo.toLowerCase(),
                                  orElse: () => <String, String>{},
                                );
                                details = person.isNotEmpty
                                    ? '${person['rank']} ${person['name']} ($armyNo)\nLogin: $username'
                                    : '$armyNo\nLogin: $username';
                              }

                              return Card(
                                color: isDark
                                    ? const Color(0xFF03140A)
                                    : const Color(
                                        0xFFE8F5EE,
                                      ).withValues(alpha: 0.4),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: goldAccent.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'SLOT $slotId - $roleLabel',
                                              style: TextStyle(
                                                color: goldAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              details,
                                              style: TextStyle(
                                                color: armyNo != null
                                                    ? textThemeColor
                                                    : silverText.withValues(
                                                        alpha: 0.6,
                                                      ),
                                                fontSize: 11,
                                                fontWeight: armyNo != null
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontStyle: armyNo != null
                                                    ? FontStyle.normal
                                                    : FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (armyNo == null)
                                            IconButton(
                                              icon: Icon(
                                                Icons
                                                    .add_circle_outline_rounded,
                                                color: valueGreenColor,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                Navigator.pop(statefulContext);
                                                Future.delayed(Duration.zero, () {
                                                  if (pageContext.mounted) {
                                                    _showSelectSoldierAdminDialog(
                                                      pageContext,
                                                      slotId,
                                                      isDark,
                                                      textThemeColor,
                                                      silverText,
                                                      goldAccent,
                                                      valueGreenColor,
                                                    );
                                                  }
                                                });
                                              },
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                            )
                                          else ...[
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                color: goldAccent,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                Navigator.pop(statefulContext);
                                                Future.delayed(Duration.zero, () {
                                                  if (pageContext.mounted) {
                                                    _showEditSlotCredentialsDialog(
                                                      pageContext,
                                                      statefulContext,
                                                      slotId,
                                                      details,
                                                      isDark,
                                                      textThemeColor,
                                                      silverText,
                                                      goldAccent,
                                                      valueGreenColor,
                                                    );
                                                  }
                                                });
                                              },
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(
                                                Icons
                                                    .remove_circle_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 18,
                                              ),
                                              onPressed: () async {
                                                await MockDataManager()
                                                    .clearSlot(slotId);
                                                setDialogState(() {});
                                                setState(() {});
                                              },
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(statefulContext),
                      child: Text(
                        'CLOSE',
                        style: TextStyle(
                          color: goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showEditSlotCredentialsDialog(
    BuildContext pageContext,
    BuildContext manageAdminsContext,
    int slotId,
    String displayName,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    showDialog(
      context: pageContext,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: MockDataManager().getCommandGroup(),
          builder: (context, snapshot) {
            final group = snapshot.data ?? [];
            final slot = group.firstWhere((s) => s['slotId'] == slotId);
            final armyNo = slot['armyNo'] as String? ?? '';
            final currentUsername = slot['username'] as String? ?? '';
            final currentPassword = slot['password'] as String? ?? '123456';

            final userController = TextEditingController(text: currentUsername);
            final passController = TextEditingController(text: currentPassword);

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: goldAccent.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              title: Text(
                'EDIT SLOT CREDENTIALS',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editing Slot $slotId credentials.',
                    style: TextStyle(color: silverText, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: userController,
                    style: TextStyle(color: textThemeColor, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: goldAccent, fontSize: 11),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF03140A)
                          : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: goldAccent.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: goldAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passController,
                    style: TextStyle(color: textThemeColor, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: goldAccent, fontSize: 11),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF03140A)
                          : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: goldAccent.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: goldAccent),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showManageAdminsDialog(
                      pageContext,
                      isDark,
                      textThemeColor,
                      silverText,
                      goldAccent,
                      valueGreenColor,
                    );
                  },
                  child: Text(
                    'CANCEL',
                    style: TextStyle(color: silverText, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final newUsername = userController.text.trim();
                    final newPassword = passController.text;

                    if (newUsername.isEmpty || newPassword.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fields cannot be empty.'),
                        ),
                      );
                      return;
                    }

                    final textLower = newUsername.toLowerCase();
                    if (textLower == 'superadmin' ||
                        textLower == 'admin' ||
                        textLower == 'user') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot overwrite system accounts.'),
                        ),
                      );
                      return;
                    }

                    // Check duplicate usernames in command group
                    var duplicate = false;
                    for (var s in group) {
                      if (s['slotId'] != slotId &&
                          s['username'].toString().toLowerCase() == textLower) {
                        duplicate = true;
                        break;
                      }
                    }
                    if (duplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Username already taken.'),
                        ),
                      );
                      return;
                    }

                    try {
                      await SupabaseRepository().updateSlotCredentials(
                        slotId,
                        armyNo,
                        newUsername,
                        newPassword,
                      );
                    } catch (e) {
                      // Silently continue if Supabase update fails or table doesn't exist yet, 
                      // but ideally it should succeed.
                    }

                    await MockDataManager().assignSlot(
                      slotId,
                      armyNo,
                      newUsername,
                      newPassword,
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _showManageAdminsDialog(
                      pageContext,
                      isDark,
                      textThemeColor,
                      silverText,
                      goldAccent,
                      valueGreenColor,
                    );

                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      const SnackBar(
                        content: Text('Slot credentials updated successfully!'),
                        backgroundColor: Color(0xFF0C5A32),
                      ),
                    );
                  },
                  child: Text(
                    'SAVE',
                    style: TextStyle(
                      color: goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangeCredentialsDialog(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
  ) {
    final armyNo = MockDataManager().adminArmyNo ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: MockDataManager().getAdminAccounts(),
          builder: (context, snapshot) {
            final accounts = snapshot.data ?? {};
            final accountData = accounts[armyNo] as Map? ?? {};
            final currentUsername =
                accountData['username'] as String? ?? armyNo;
            final currentPassword =
                accountData['password'] as String? ?? '123456';

            final userController = TextEditingController(text: currentUsername);
            final passController = TextEditingController(text: currentPassword);

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: goldAccent.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              title: Text(
                'UPDATE MY CREDENTIALS',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userController,
                    style: TextStyle(color: textThemeColor, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: goldAccent, fontSize: 11),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF03140A)
                          : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: goldAccent.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: goldAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passController,
                    style: TextStyle(color: textThemeColor, fontSize: 13),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: goldAccent, fontSize: 11),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF03140A)
                          : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: goldAccent.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: goldAccent),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(color: silverText, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final newUsername = userController.text.trim();
                    final newPassword = passController.text;

                    if (newUsername.isEmpty || newPassword.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fields cannot be empty.'),
                        ),
                      );
                      return;
                    }

                    final textLower = newUsername.toLowerCase();
                    if (textLower == 'superadmin' ||
                        textLower == 'admin' ||
                        textLower == 'user') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot overwrite system accounts.'),
                        ),
                      );
                      return;
                    }

                    var duplicate = false;
                    for (var entry in accounts.entries) {
                      if (entry.key != armyNo &&
                          (entry.value as Map)['username']
                                  .toString()
                                  .toLowerCase() ==
                              textLower) {
                        duplicate = true;
                        break;
                      }
                    }
                    if (duplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Username already taken.'),
                        ),
                      );
                      return;
                    }

                    await MockDataManager().updateCredentials(
                      armyNo,
                      newUsername,
                      newPassword,
                    );
                    MockDataManager().login(
                      newUsername,
                      'Data Entry',
                      adminArmyNo: armyNo,
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    setState(() {});

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Credentials updated successfully!'),
                        backgroundColor: Color(0xFF0C5A32),
                      ),
                    );
                  },
                  child: Text(
                    'SAVE',
                    style: TextStyle(
                      color: goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSelectSoldierAdminDialog(
    BuildContext pageContext,
    int slotId,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    String query = '';

    showDialog(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: MockDataManager().getCommandGroup(),
              builder: (context, snapshot) {
                final group = snapshot.data ?? [];
                // Exclude soldiers already assigned to any slot
                final assignedArmyNos = group
                    .where((s) => s['armyNo'] != null)
                    .map((s) => s['armyNo'] as String)
                    .toList();

                final filtered = nominalRollList.where((p) {
                  final armyNo = p['armyNo'] ?? '';
                  if (assignedArmyNos.contains(armyNo)) return false;

                  if (query.isEmpty) return true;

                  final name = (p['name'] ?? '').toLowerCase();
                  final rank = (p['rank'] ?? '').toLowerCase();
                  final no = armyNo.toLowerCase();
                  return name.contains(query) ||
                      rank.contains(query) ||
                      no.contains(query);
                }).toList();

                return AlertDialog(
                  backgroundColor: isDark
                      ? const Color(0xFF0A2214)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: goldAccent.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  title: Text(
                    'ASSIGN SOLDIER TO SLOT $slotId',
                    style: TextStyle(
                      color: goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.95,
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Column(
                      children: [
                        TextFormField(
                          style: TextStyle(color: textThemeColor, fontSize: 13),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.search,
                              color: goldAccent,
                              size: 16,
                            ),
                            hintText: 'Search by Name, Rank, or Army No...',
                            hintStyle: TextStyle(
                              color: silverText.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF03140A)
                                : const Color(
                                    0xFFE8F5EE,
                                  ).withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: goldAccent.withValues(alpha: 0.15),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: goldAccent),
                            ),
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              query = val.trim().toLowerCase();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    'No matching soldiers found.',
                                    style: TextStyle(
                                      color: silverText,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final person = filtered[index];
                                    final armyNo = person['armyNo'] ?? '';
                                    final name = person['name'] ?? '';
                                    final rank = person['rank'] ?? '';

                                    return Card(
                                      color: isDark
                                          ? const Color(0xFF03140A)
                                          : const Color(
                                              0xFFE8F5EE,
                                            ).withValues(alpha: 0.3),
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: goldAccent.withValues(
                                            alpha: 0.1,
                                          ),
                                        ),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          '$rank $name',
                                          style: TextStyle(
                                            color: textThemeColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Army No: $armyNo',
                                          style: TextStyle(
                                            color: valueGreenColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () async {
                                            if (!statefulContext.mounted) {
                                              return;
                                            }
                                            Navigator.pop(statefulContext);
                                            Future.delayed(Duration.zero, () {
                                              if (pageContext.mounted) {
                                                _showSetCredentialsDialog(
                                                  pageContext,
                                                  statefulContext,
                                                  slotId,
                                                  armyNo,
                                                  rank,
                                                  name,
                                                  isDark,
                                                  textThemeColor,
                                                  silverText,
                                                  goldAccent,
                                                  valueGreenColor,
                                                );
                                              }
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0C5A32,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: const Text(
                                            'SELECT',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(statefulContext);
                        Future.delayed(Duration.zero, () {
                          if (pageContext.mounted) {
                            _showManageAdminsDialog(
                              pageContext,
                              isDark,
                              textThemeColor,
                              silverText,
                              goldAccent,
                              valueGreenColor,
                            );
                          }
                        });
                      },
                      child: Text(
                        'BACK',
                        style: TextStyle(
                          color: goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSetCredentialsDialog(
    BuildContext pageContext,
    BuildContext statefulContext,
    int slotId,
    String armyNo,
    String rank,
    String name,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final userController = TextEditingController(text: armyNo);
    final passController = TextEditingController(text: '123456');

    showDialog(
      context: pageContext,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: goldAccent.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          title: Text(
            'SET ADMIN CREDENTIALS',
            style: TextStyle(
              color: goldAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Assign login credentials for $rank $name ($armyNo).',
                style: TextStyle(color: silverText, fontSize: 11),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userController,
                style: TextStyle(color: textThemeColor, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: goldAccent, fontSize: 11),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF03140A)
                      : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: goldAccent.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: goldAccent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                style: TextStyle(color: textThemeColor, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: goldAccent, fontSize: 11),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF03140A)
                      : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: goldAccent.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: goldAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSelectSoldierAdminDialog(
                  pageContext,
                  slotId,
                  isDark,
                  textThemeColor,
                  silverText,
                  goldAccent,
                  valueGreenColor,
                );
              },
              child: Text(
                'CANCEL',
                style: TextStyle(color: silverText, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () async {
                final username = userController.text.trim();
                final password = passController.text;

                if (username.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fields cannot be empty.')),
                  );
                  return;
                }

                final textLower = username.toLowerCase();
                if (textLower == 'superadmin' ||
                    textLower == 'admin' ||
                    textLower == 'user') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cannot overwrite system accounts.'),
                    ),
                  );
                  return;
                }

                final group = await MockDataManager().getCommandGroup();
                if (!context.mounted) return;
                var duplicate = false;
                for (var s in group) {
                  if (s['username'].toString().toLowerCase() == textLower) {
                    duplicate = true;
                    break;
                  }
                }
                if (duplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username already taken.')),
                  );
                  return;
                }

                await MockDataManager().assignSlot(
                  slotId,
                  armyNo,
                  username,
                  password,
                );
                setState(() {});

                if (!context.mounted) return;
                Navigator.pop(context);
                _showManageAdminsDialog(
                  pageContext,
                  isDark,
                  textThemeColor,
                  silverText,
                  goldAccent,
                  valueGreenColor,
                );

                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$rank $name is now assigned to Slot $slotId!',
                    ),
                    backgroundColor: const Color(0xFF0C5A32),
                  ),
                );
              },
              child: Text(
                'CREATE',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSystemProfileDialog(
    BuildContext context,
    String displayName,
    String roleLabel,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: goldAccent.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          title: Text(
            'SYSTEM CONSOLE PROFILE',
            style: TextStyle(
              color: goldAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: isDark
                      ? const Color(0xFF03140A)
                      : const Color(0xFFE8F5EE),
                  child: Icon(
                    Icons.shield_rounded,
                    color: goldAccent,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: textThemeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'ROLE: $roleLabel',
                  style: TextStyle(
                    color: goldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.grey, height: 1),
              const SizedBox(height: 12),
              _buildProfileDetailRow(
                'System Level:',
                'Regimental HQ Core Console',
                isDark ? Colors.white : Colors.black,
              ),
              _buildProfileDetailRow(
                'Authentication:',
                'Hardcoded System Bypass',
                isDark ? Colors.white : Colors.black,
              ),
              _buildProfileDetailRow(
                'Operation Privileges:',
                roleLabel == 'SUPER ADMIN'
                    ? 'Full Read/Write/Admin Access'
                    : (roleLabel == 'ADMIN'
                          ? 'Read/Write Status updates'
                          : 'Read-only view access'),
                isDark ? Colors.white : Colors.black,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CLOSE',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
  ) {
    final currentUsername = MockDataManager().username ?? '';
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: goldAccent.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          title: Text(
            'CHANGE PASSWORD',
            style: TextStyle(
              color: goldAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPassController,
                style: TextStyle(color: textThemeColor, fontSize: 13),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: goldAccent, fontSize: 11),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF03140A)
                      : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: goldAccent.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: goldAccent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassController,
                style: TextStyle(color: textThemeColor, fontSize: 13),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: goldAccent, fontSize: 11),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF03140A)
                      : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: goldAccent.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: goldAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(color: silverText, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () async {
                final newPass = newPassController.text;
                final confirmPass = confirmPassController.text;

                if (newPass.isEmpty || confirmPass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password fields cannot be empty.'),
                    ),
                  );
                  return;
                }

                if (newPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match.')),
                  );
                  return;
                }

                await MockDataManager().changePassword(
                  currentUsername,
                  newPass,
                );
                if (!context.mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully!'),
                    backgroundColor: Color(0xFF0C5A32),
                  ),
                );
              },
              child: Text(
                'SAVE',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final currentUsername = MockDataManager().username ?? 'SUPERADMIN';
    final role = MockDataManager().role ?? 'Administrator';
    final armyNo = MockDataManager().adminArmyNo;

    String displayName = currentUsername.toUpperCase();
    String subDetails = 'System Account';
    String avatarUrl = '';

    if (armyNo != null) {
      final person = nominalRollList.firstWhere(
        (p) => (p['armyNo'] ?? '').toLowerCase() == armyNo.toLowerCase(),
        orElse: () => <String, String>{},
      );
      if (person.isNotEmpty) {
        displayName = '${person['rank']} ${person['name']}';
        subDetails = 'Army No: ${person['armyNo']} • ${person['trade']}';
        avatarUrl = person['avatar'] ?? '';
      }
    } else {
      if (currentUsername.toLowerCase() == 'superadmin') {
        displayName = 'REGIMENTAL SUPER ADMIN';
      } else if (currentUsername.toLowerCase() == 'admin') {
        displayName = 'SYSTEM DATA ENTRY ADMIN';
      } else if (currentUsername.toLowerCase() == 'user') {
        displayName = 'GUEST AUDITOR';
      }
    }

    String roleLabel = 'VIEW-ONLY';
    if (role == 'Administrator') roleLabel = 'SUPER ADMIN';
    if (role == 'Data Entry') roleLabel = 'ADMIN';

    return GestureDetector(
      onTap: () {
        if (armyNo != null) {
          final person = nominalRollList.firstWhere(
            (p) => (p['armyNo'] ?? '').toLowerCase() == armyNo.toLowerCase(),
            orElse: () => <String, String>{},
          );
          if (person.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PersonnelIdCardScreen(
                  person: person,
                  isDark: isDark,
                  textThemeColor: textThemeColor,
                  silverText: silverText,
                  goldAccent: goldAccent,
                  valueGreenColor: valueGreenColor,
                ),
              ),
            );
          }
        } else {
          _showSystemProfileDialog(
            context,
            displayName,
            roleLabel,
            isDark,
            textThemeColor,
            silverText,
            goldAccent,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0C5A32).withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? goldAccent.withValues(alpha: 0.25)
                : const Color(0xFF0C5A32).withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: goldAccent.withValues(alpha: 0.15),
              child: ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _buildAvatarImage(avatarUrl),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: textThemeColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subDetails,
                    style: TextStyle(
                      color: silverText.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: role == 'Administrator'
                          ? goldAccent.withValues(alpha: 0.15)
                          : (role == 'Data Entry'
                                ? valueGreenColor.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: role == 'Administrator'
                            ? goldAccent
                            : (role == 'Data Entry'
                                  ? valueGreenColor
                                  : Colors.blue),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      roleLabel,
                      style: TextStyle(
                        color: role == 'Administrator'
                            ? goldAccent
                            : (role == 'Data Entry'
                                  ? valueGreenColor
                                  : Colors.blue),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final shortYear = (date.year % 100).toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} $shortYear';
  }

  String _formatDateRange(DateTime date, {bool includeYear = true}) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final shortYear = (date.year % 100).toString().padLeft(2, '0');
    final base =
        '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
    return includeYear ? '$base $shortYear' : base;
  }

  Future<void> _exportHistoryExcel(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final manager = PersonnelDataManager();
      final rows = <List<dynamic>>[
        [
          'Army No',
          'Name',
          'Rank',
          'Trade',
          'Current Status',
          'History Start',
          'History End',
          'Movement Path',
        ],
      ];

      for (final person in nominalRollList) {
        final armyNo = person['armyNo'] ?? '';
        final name = person['name'] ?? '';
        final rank = person['rank'] ?? '';
        final trade = _getTrade(person);
        final status = manager.getStatus(armyNo);
        final history = await manager.getHistory(armyNo);

        if (history.isEmpty) {
          rows.add([armyNo, name, rank, trade, status.category, '', '', '']);
          continue;
        }

        for (final entry in history) {
          rows.add([
            armyNo,
            name,
            rank,
            trade,
            entry.category,
            _formatDate(entry.startDate),
            entry.endDate != null ? _formatDate(entry.endDate!) : 'Ongoing',
            entry.displayPath.replaceAll(' -> ', ' → '),
          ]);
        }
      }

      final csvData = const csv.CsvEncoder().convert(rows);
      final csvBytes = Uint8List.fromList(utf8.encode(csvData));
      
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}_${now.month.toString().padLeft(2, '0')}_${now.year}';

      await saveAndDownloadFile(
        filename: 'personnel_history_export_$dateStr.csv',
        bytes: csvBytes,
        mimeType: 'text/csv',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? 'Excel export download started'
              : 'Excel export saved to downloads directory'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
        ),
      ),
    );
  }

  pw.Widget _buildPdfCategoryCard(
    String displayTitle,
    List<Map<String, String>> people,
    int totalCount,
    PersonnelDataManager manager,
    PdfColor primaryColor,
    PdfColor accentColor,
    PdfColor borderColor,
    PdfColor lightBg,
    PdfColor darkText,
  ) {
    final List<pw.TableRow> tableRows = [];

    for (var person in people) {
      final rank = person['rank'] ?? '';
      final name = person['name'] ?? '';
      final status = manager.getStatus(person['armyNo'] ?? '');
      
      String duty = '';
      if (false) {
        
      } else if (status.subcategory != null && status.subcategory!.isNotEmpty) {
        duty = status.subcategory!;
      }

      tableRows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              child: pw.Text('$rank $name', style: pw.TextStyle(fontSize: 8, color: darkText)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              child: pw.Text(duty, style: pw.TextStyle(fontSize: 8, color: darkText)),
            ),
          ],
        )
      );
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Card Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  displayTitle,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                pw.Text(
                  '$totalCount',
                  style: pw.TextStyle(
                    color: accentColor,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Subcategory lists
          pw.Container(
            padding: const pw.EdgeInsets.all(2),
            color: lightBg,
            child: people.isEmpty
                ? pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'No Individuals',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                  )
                : pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                    },
                    children: tableRows,
                  ),
          ),
        ],
      ),
    );
  }


  Future<void> _exportHistoryPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final manager = PersonnelDataManager();

      // Must set a default font for web compatibility — pdf package
      // cannot access system fonts on web, so we use the built-in Helvetica.
      final baseFont = pw.Font.helvetica();
      final boldFont = pw.Font.helveticaBold();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
        ),
      );

      final now = DateTime.now();
      final dateStr = '${now.day} ${_getMonthName(now.month)} ${now.year}';

      final primaryColor = PdfColor.fromHex('#0C5A32');
      final accentColor = PdfColor.fromHex('#CD9B2D');
      final darkText = PdfColor.fromHex('#042011');
      final lightBg = PdfColor.fromHex('#F4F9F6');
      final borderColor = PdfColor.fromHex('#D0DFD7');

      int totalStrength = nominalRollList.length;
      int officersCount = 0;
      int jcosCount = 0;
      int sldrsCount = 0;

      for (var person in nominalRollList) {
        final cat = _getRankCategory(person['rank'] ?? '', person['name'] ?? '');
        if (cat == 'OFFICERS') {
          officersCount++;
        } else if (cat == 'JCOs') {
          jcosCount++;
        } else {
          sldrsCount++;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
              child: pw.Text(
                'ZARB-UL-HADEED - PARADE STATE REPORT',
                style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                'Page ${context.pageNumber}',
                style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // ── Header banner ──────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ZARB-UL-HADEED',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '117 SP REGT. - PARADE STATE REPORT',
                          style: pw.TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      dateStr,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // ── Section title ──────────────────────────────────
              pw.Text(
                'Strength & Category Analysis',
                style: pw.TextStyle(
                  color: primaryColor,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: 2, color: accentColor, width: 80),
              pw.SizedBox(height: 20),

              // ── Rank summary table ─────────────────────────────
              pw.Text(
                'Personnel Strengths Summary',
                style: pw.TextStyle(
                  color: darkText,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _buildTableHeaderCell('Category / Group'),
                      _buildTableHeaderCell('Count'),
                      _buildTableHeaderCell('Percentage'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Officers'),
                      _buildTableCell('$officersCount'),
                      _buildTableCell(totalStrength > 0 ? '${(officersCount / totalStrength * 100).toStringAsFixed(1)}%' : '0%'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('JCOs'),
                      _buildTableCell('$jcosCount'),
                      _buildTableCell(totalStrength > 0 ? '${(jcosCount / totalStrength * 100).toStringAsFixed(1)}%' : '0%'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Soldiers (Sldrs)'),
                      _buildTableCell('$sldrsCount'),
                      _buildTableCell(totalStrength > 0 ? '${(sldrsCount / totalStrength * 100).toStringAsFixed(1)}%' : '0%'),
                    ],
                  ),
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _buildTableCell('Total Strength', isBold: true),
                      _buildTableCell('$totalStrength', isBold: true),
                      _buildTableCell('100%', isBold: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // ── Category table ─────────────────────────────────
              pw.Text(
                'Main Categories Strength',
                style: pw.TextStyle(
                  color: darkText,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _buildTableHeaderCell('Category'),
                      _buildTableHeaderCell('Current Count'),
                      _buildTableHeaderCell('% of Total'),
                    ],
                  ),
                  ...manager.categoryHierarchy.keys.map((cat) {
                    final count = manager.getCountForCategory(cat);
                    final pct = totalStrength > 0 ? (count / totalStrength * 100).toStringAsFixed(1) : '0';
                    return pw.TableRow(
                      children: [
                        _buildTableCell(cat),
                        _buildTableCell('$count'),
                        _buildTableCell('$pct%'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 32),

              // ── Category-wise detail cards ─────────────────────
              pw.Text(
                'Category-Wise Distribution Details',
                style: pw.TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),

              pw.Wrap(
                spacing: 16,
                runSpacing: 0,
                children: manager.categoryHierarchy.keys.expand((cat) {
                  final people = manager.getPeopleInNode(category: cat);
                  final totalCount = manager.getCountForCategory(cat);
                  
                  if (people.isEmpty) {
                    return [
                      pw.Container(
                        width: (PdfPageFormat.a4.availableWidth - 16) / 2,
                        child: _buildPdfCategoryCard(cat, [], totalCount, manager, primaryColor, accentColor, borderColor, lightBg, darkText),
                      )
                    ];
                  }

                  // Helper function to chunk people list
                  List<List<Map<String, String>>> chunkPeopleList(List<Map<String, String>> list, int size) {
                    List<List<Map<String, String>>> chunks = [];
                    for (var i = 0; i < list.length; i += size) {
                      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
                    }
                    return chunks;
                  }

                  final chunks = chunkPeopleList(people, 12);
                  return chunks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final chunkPeople = entry.value;
                    final totalChunks = chunks.length;
                    final titleSuffix = totalChunks > 1 ? ' (${index + 1}/$totalChunks)' : '';
                    
                    return pw.Container(
                      width: (PdfPageFormat.a4.availableWidth - 16) / 2,
                      child: _buildPdfCategoryCard('$cat$titleSuffix', chunkPeople, totalCount, manager, primaryColor, accentColor, borderColor, lightBg, darkText),
                    );
                  });
                }).toList(),
              ),
            ];
          },
        ),
      );



      final pdfBytes = await pdf.save();
      
      final pdfNow = DateTime.now();
      final pdfDateStr = '${pdfNow.day.toString().padLeft(2, '0')}_${pdfNow.month.toString().padLeft(2, '0')}_${pdfNow.year}';

      // Save the PDF and get the file path (or URL on web)
      final String pdfPath = await saveAndDownloadFile(
        filename: 'personnel_history_report_$pdfDateStr.pdf',
        bytes: pdfBytes,
        mimeType: 'application/pdf',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      // Show a dialog with the PDF path and allow opening it
      _showPdfPathDialog(context, pdfPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? 'PDF report download started'
              : 'PDF exported to downloads directory'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('PDF export error: $e\n$stack');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }
  void _showPdfPathDialog(BuildContext context, String path) {
    if (kIsWeb) return; // On web, download is triggered automatically
    
    final isDark = widget.isDarkMode;
    final textThemeColor = isDark ? Colors.white : const Color(0xFF042011);
    final silverText = isDark ? const Color(0xFFE5E5E5) : const Color(0xFF4A5D52);
    final goldAccent = isDark ? const Color(0xFFCD9B2D) : const Color(0xFF9E7715);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF051C0F) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? goldAccent.withValues(alpha: 0.3)
                : const Color(0xFF0C5A32).withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              'PDF Saved Successfully',
              style: TextStyle(
                color: textThemeColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your PDF report has been saved to:',
              style: TextStyle(color: silverText, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0C5A32).withValues(alpha: 0.08)
                    : const Color(0xFF0C5A32).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? goldAccent.withValues(alpha: 0.15)
                      : const Color(0xFF0C5A32).withValues(alpha: 0.08),
                ),
              ),
              child: SelectableText(
                path,
                style: TextStyle(
                  color: textThemeColor,
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: Tap the button below to view the PDF directly.',
              style: TextStyle(
                color: goldAccent,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? silverText : Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C5A32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text(
              'View PDF',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final result = await OpenFile.open(path);
              if (mounted && result.type != ResultType.done) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text(
                      'Could not open file: ${result.message}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDownloadHistoryOptionsSheet(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF051C0F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DOWNLOAD HISTORY',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.picture_as_pdf_rounded, color: goldAccent),
                title: Text(
                  'Download PDF',
                  style: TextStyle(
                    color: textThemeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  'Create a PDF report with all users and movement history',
                  style: TextStyle(color: silverText, fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _exportHistoryPdf(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final isSuperAdmin = MockDataManager().role == 'Administrator';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 80.0),
          Row(
            children: [
              Icon(Icons.settings_rounded, color: goldAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                'SETTINGS CENTRE',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // 1. Profile Header
                _buildProfileHeader(
                  context,
                  isDark,
                  textThemeColor,
                  silverText,
                  goldAccent,
                  valueGreenColor,
                ),
                const SizedBox(height: 16),

                // Change Password Tile
                _buildSettingsModuleCard(
                  isDark,
                  goldAccent,
                  child: ListTile(
                    leading: Icon(
                      Icons.vpn_key_rounded,
                      color: goldAccent,
                      size: 20,
                    ),
                    title: Text(
                      'Change My Password',
                      style: TextStyle(
                        color: textThemeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'Change your login password credential',
                      style: TextStyle(color: silverText, fontSize: 11),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: goldAccent,
                      size: 18,
                    ),
                    onTap: () {
                      _showChangePasswordDialog(
                        context,
                        isDark,
                        textThemeColor,
                        silverText,
                        goldAccent,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 2. App Theme Mode
                _buildSettingsModuleCard(
                  isDark,
                  goldAccent,
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.palette_outlined,
                      color: goldAccent,
                      size: 20,
                    ),
                    title: Text(
                      'App Theme Mode',
                      style: TextStyle(
                        color: textThemeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      isDark ? 'Dark Mode Active' : 'Light Theme Active',
                      style: TextStyle(color: silverText, fontSize: 11),
                    ),
                    value: isDark,
                    onChanged: (val) {
                      widget.onToggleTheme();
                    },
                    activeThumbColor: goldAccent,
                    activeTrackColor: const Color(0xFF0C5A32),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Manage Command Group (Superadmin & Admin)
                if (isSuperAdmin || MockDataManager().role == 'Data Entry') ...[
                  _buildSettingsModuleCard(
                    isDark,
                    goldAccent,
                    child: ListTile(
                      leading: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: goldAccent,
                        size: 20,
                      ),
                      title: Text(
                        'Manage Command Group',
                        style: TextStyle(
                          color: textThemeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'Configure the 12 security console accounts',
                        style: TextStyle(color: silverText, fontSize: 11),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: goldAccent,
                        size: 18,
                      ),
                      onTap: () {
                        _showManageAdminsDialog(
                          context,
                          isDark,
                          textThemeColor,
                          silverText,
                          goldAccent,
                          valueGreenColor,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 3.5 Manage App Attributes (Superadmin Only)
                  if (isSuperAdmin) ...[
                    _buildSettingsModuleCard(
                      isDark,
                      goldAccent,
                      child: ListTile(
                        leading: Icon(
                          Icons.list_alt_rounded,
                          color: goldAccent,
                          size: 20,
                        ),
                        title: Text(
                          'Manage App Attributes',
                          style: TextStyle(
                            color: textThemeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'Configure Trades, Ranks, and Batteries',
                          style: TextStyle(color: silverText, fontSize: 11),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: goldAccent,
                          size: 18,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageAttributesScreen(
                                isDark: isDark,
                                textThemeColor: textThemeColor,
                                silverText: silverText,
                                goldAccent: goldAccent,
                                valueGreenColor: valueGreenColor,
                              ),
                            ),
                          );
                          _loadDynamicAttributes();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                // 3.6 View All Groups (For Everyone)
                _buildSettingsModuleCard(
                  isDark,
                  goldAccent,
                  child: ListTile(
                    leading: Icon(
                      Icons.group_rounded,
                      color: goldAccent,
                      size: 20,
                    ),
                    title: Text(
                      'View All Groups',
                      style: TextStyle(
                        color: textThemeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'View all Admins, Users and Superadmin',
                      style: TextStyle(color: silverText, fontSize: 11),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: goldAccent,
                      size: 18,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewAllGroupsScreen(
                            isDark: isDark,
                            textThemeColor: textThemeColor,
                            silverText: silverText,
                            goldAccent: goldAccent,
                            valueGreenColor: valueGreenColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Change My Credentials (Admin Only)
                if (MockDataManager().role == 'Data Entry' &&
                    MockDataManager().adminArmyNo != null) ...[
                  _buildSettingsModuleCard(
                    isDark,
                    goldAccent,
                    child: ListTile(
                      leading: Icon(
                        Icons.manage_accounts_rounded,
                        color: goldAccent,
                        size: 20,
                      ),
                      title: Text(
                        'Change My Credentials',
                        style: TextStyle(
                          color: textThemeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: const Text(
                        'Update username and password credentials',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: goldAccent,
                        size: 18,
                      ),
                      onTap: () {
                        _showChangeCredentialsDialog(
                          context,
                          isDark,
                          textThemeColor,
                          silverText,
                          goldAccent,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 5. Download History Records
                _buildSettingsModuleCard(
                  isDark,
                  goldAccent,
                  child: ListTile(
                    leading: Icon(
                      Icons.download_rounded,
                      color: goldAccent,
                      size: 20,
                    ),
                    title: Text(
                      'Download History',
                      style: TextStyle(
                        color: textThemeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'Download PDF report with all personnel history',
                      style: TextStyle(color: silverText, fontSize: 11),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: goldAccent,
                      size: 18,
                    ),
                    onTap: () {
                      _showDownloadHistoryOptionsSheet(
                        context,
                        isDark,
                        textThemeColor,
                        silverText,
                        goldAccent,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 6. Logout Session
                _buildSettingsModuleCard(
                  isDark,
                  goldAccent,
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    title: const Text(
                      'Logout Session',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'Securely exit your console session',
                      style: TextStyle(color: silverText, fontSize: 11),
                    ),
                    onTap: () {
                      MockDataManager().logout();
                      widget.onLogout();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsModuleCard(
    bool isDark,
    Color goldAccent, {
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: isDark
          ? const Color(0xFF0C5A32).withValues(alpha: 0.12)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? goldAccent.withValues(alpha: 0.15)
              : const Color(0xFF0C5A32).withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }

  Future<void> _showPersonFormDialog(
    BuildContext context, {
    Map<String, String>? personToEdit,
    required bool isDark,
    required Color textThemeColor,
    required Color silverText,
    required Color goldAccent,
    required Color valueGreenColor,
  }) async {
    final manager = PersonnelDataManager();
    final mockData = MockDataManager();

    final armyNoController = TextEditingController(
      text: personToEdit?['armyNo'] ?? '',
    );
    final nameController = TextEditingController(
      text: personToEdit?['name'] ?? '',
    );
    final phoneController = TextEditingController(
      text: personToEdit?['phone'] ?? '',
    );
    final cityController = TextEditingController(
      text: personToEdit?['city'] ?? '',
    );
    final remarksController = TextEditingController(
      text: personToEdit?['remarks'] ?? '',
    );

    String avatarSelection = personToEdit?['avatar'] ?? '';

    bool isFighting = true;
    if (personToEdit != null) {
      isFighting = _isFighting(personToEdit);
    }
    String fightingSelection = isFighting ? 'Fighting' : 'Non Fighting';

    // Load trades from Supabase (authoritative source), fallback to SharedPreferences
    List<String> rawTrades = [];
    try {
      rawTrades = await SupabaseRepository().getSystemAttributeItems('trades');
    } catch (_) {}
    if (rawTrades.isEmpty) {
      rawTrades = await mockData.getTrades();
    }
    final List<String> trades = rawTrades
        .where((t) => t.toLowerCase() != 'all' && t.trim().isNotEmpty)
        .toList();

    String tradeSelection =
        personToEdit?['trade'] ?? personToEdit?['category'] ?? '';
    if (trades.isNotEmpty && !trades.contains(tradeSelection)) {
      tradeSelection = trades.first;
    }

    // Load ranks from Supabase (authoritative source), fallback to SharedPreferences
    List<String> rawRanks = [];
    try {
      rawRanks = await SupabaseRepository().getSystemAttributeItems('ranks');
    } catch (_) {}
    if (rawRanks.isEmpty) {
      rawRanks = await mockData.getRanks();
    }
    // Keep only actual rank entries (trim leading spaces); exclude 'All' and blank
    final List<String> ranks = rawRanks
        .where((r) => r.toLowerCase() != 'all' && r.trim().isNotEmpty)
        .map((r) => r.trim())
        .toList();

    String rankSelection = (personToEdit?['rank'] ?? '').trim();
    if (ranks.isNotEmpty && !ranks.contains(rankSelection)) {
      rankSelection = ranks.first;
    }

    String clSelection = personToEdit?['cl'] ?? 'Pb';
    final List<String> classes = ['Pb', 'Ptn', 'Sdh', 'Blh', 'AJK', 'GB'];
    if (!classes.contains(clSelection)) {
      classes.add(clSelection);
    }

    // Load batteries from Supabase (authoritative source), fallback to hardcoded
    List<String> rawBatteries = [];
    try {
      rawBatteries = await SupabaseRepository().getSystemAttributeItems('batteries');
    } catch (_) {}
    if (rawBatteries.isEmpty) {
      rawBatteries = await mockData.getBatteries();
    }
    final List<String> batteries = rawBatteries
        .where((b) => b.toLowerCase() != 'all' && b.trim().isNotEmpty)
        .toList();
    // Fallback to hardcoded if still empty
    if (batteries.isEmpty) {
      batteries.addAll(['HQ Bty', 'P Bty', 'Q Bty', 'R Bty']);
    }

    String batterySelection = personToEdit?['battery'] ?? (personToEdit != null ? _getBattery(personToEdit) : '');
    if (batterySelection.isEmpty || !batteries.contains(batterySelection)) {
      batterySelection = batteries.first;
    }

    String categorySelection = personToEdit?['category'] ?? 'Gnrs';
    final List<String> categories = [
      'Officers',
      'JCOs',
      'Clks',
      'Svys',
      'TAs',
      'OCsU',
      'DSVs',
      'DMTs',
      'Gnrs',
      'C/Us',
      'SWs',
      'NCBs',
      'Civs',
      'LADs',
    ];
    if (!categories.contains(categorySelection)) {
      categories.add(categorySelection);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0A2214) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: goldAccent.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              title: Text(
                personToEdit == null ? 'ADD NEW PERSONNEL' : 'EDIT PERSONNEL',
                style: TextStyle(
                  color: goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Picture selection inside Form
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final base64 = await _pickImageAsBase64();
                                if (base64 != null) {
                                  setDialogState(() {
                                    avatarSelection = base64;
                                  });
                                }
                              },
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: goldAccent.withValues(alpha: 0.3),
                                    child: ClipOval(
                                      child: _buildAvatarImage(avatarSelection),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: goldAccent,
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to update photo',
                              style: TextStyle(
                                color: silverText.withValues(alpha: 0.6),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Fighting dropdown
                      Text(
                        'FIGHTING / NON FIGHTING *',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF03140A)
                              : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: fightingSelection,
                            dropdownColor: isDark
                                ? const Color(0xFF0A2214)
                                : Colors.white,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'Fighting',
                                child: Text('Fighting'),
                              ),
                              DropdownMenuItem(
                                value: 'Non Fighting',
                                child: Text('Non Fighting'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  fightingSelection = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFormTextField(
                        'ARMY NUMBER *',
                        armyNoController,
                        'e.g. 1234567...',
                        silverText,
                        textThemeColor,
                        isDark,
                        goldAccent,
                        enabled: personToEdit == null,
                      ),
                      const SizedBox(height: 12),
                      _buildFormTextField(
                        'FULL NAME *',
                        nameController,
                        'Enter full name...',
                        silverText,
                        textThemeColor,
                        isDark,
                        goldAccent,
                      ),
                      const SizedBox(height: 12),

                      // Trade dropdown
                      Text(
                        'TRADE *',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF03140A)
                              : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: tradeSelection,
                            dropdownColor: isDark
                                ? const Color(0xFF0A2214)
                                : Colors.white,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 12,
                            ),
                            isExpanded: true,
                            items: trades
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  tradeSelection = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Rank dropdown
                      Text(
                        'RANK *',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF03140A)
                              : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: rankSelection,
                            dropdownColor: isDark
                                ? const Color(0xFF0A2214)
                                : Colors.white,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 12,
                            ),
                            isExpanded: true,
                            items: ranks
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  rankSelection = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category dropdown
                      Text(
                        'CATEGORY *',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF03140A)
                              : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: categorySelection,
                            dropdownColor: isDark
                                ? const Color(0xFF0A2214)
                                : Colors.white,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 12,
                            ),
                            isExpanded: true,
                            items: categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  categorySelection = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Class dropdown
                      Text(
                        'CLASS *',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF03140A)
                              : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: clSelection,
                            dropdownColor: isDark
                                ? const Color(0xFF0A2214)
                                : Colors.white,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 12,
                            ),
                            isExpanded: true,
                            items: classes
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  clSelection = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Battery dropdown
                      Text(
                        'BATTERY *',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF03140A)
                              : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: batterySelection,
                            dropdownColor: isDark
                                ? const Color(0xFF0A2214)
                                : Colors.white,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 12,
                            ),
                            isExpanded: true,
                            items: batteries
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  batterySelection = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFormTextField(
                        'PHONE NUMBER',
                        phoneController,
                        'Enter phone number...',
                        silverText,
                        textThemeColor,
                        isDark,
                        goldAccent,
                        isPhone: true,
                      ),
                      const SizedBox(height: 12),
                      _buildFormTextField(
                        'CITY',
                        cityController,
                        'Enter city name...',
                        silverText,
                        textThemeColor,
                        isDark,
                        goldAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildFormTextField(
                        'REMARKS / OBSERVATIONS',
                        remarksController,
                        'Enter remarks...',
                        silverText,
                        textThemeColor,
                        isDark,
                        goldAccent,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: silverText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final armyNo = armyNoController.text.trim();
                    final name = nameController.text.trim();

                    if (armyNo.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all required fields (*)'),
                        ),
                      );
                      return;
                    }

                    final dataMap = {
                      'armyNo': armyNo,
                      'name': name,
                      'trade': tradeSelection,
                      'category': categorySelection,
                      'rank': rankSelection,
                      'cl': clSelection,
                      'battery': batterySelection,
                      'phone': phoneController.text.trim(),
                      'city': cityController.text.trim(),
                      'remarks': remarksController.text.trim(),
                      'isFighting': fightingSelection == 'Fighting'
                          ? 'true'
                          : 'false',
                      'avatar': avatarSelection,
                    };

                    if (personToEdit == null) {
                      await manager.addPerson(dataMap);
                    } else {
                      await manager.editPerson(personToEdit['armyNo']!, dataMap);
                    }

                    setState(() {});
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          personToEdit == null
                              ? 'Successfully added $name!'
                              : 'Successfully updated $name!',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFF0C5A32),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C5A32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    personToEdit == null ? 'ADD PERSONNEL' : 'SAVE CHANGES',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFormTextField(
    String label,
    TextEditingController controller,
    String hint,
    Color labelColor,
    Color textColor,
    bool isDark,
    Color goldAccent, {
    bool enabled = true,
    bool isPhone = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: TextStyle(color: textColor, fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: labelColor.withValues(alpha: 0.4),
              fontSize: 11,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF03140A)
                : const Color(0xFFE8F5EE).withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: goldAccent.withValues(alpha: 0.15)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: labelColor.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: goldAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color valueColor,
    required Color labelColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDivider(Color color, bool isDark) {
    return Container(
      width: 1,
      height: 25,
      color: isDark
          ? color.withValues(alpha: 0.25)
          : const Color(0xFF0C5A32).withValues(alpha: 0.2),
    );
  }

  Widget _buildDetailsPanel({
    required String title,
    required bool isDark,
    required Color goldAccent,
    required Color silverText,
    required Color textThemeColor,
    required Color bulletColor,
    required List<Widget> columns,
  }) {
    final isExpanded = _expandedSections.contains(title);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C5A32).withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? goldAccent.withValues(alpha: 0.35)
              : const Color(0xFF0C5A32).withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : const Color(0xFF0C5A32).withValues(alpha: 0.04),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tapping area
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _dashVM.toggleSection(title);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Green Title Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF03140A).withValues(alpha: 0.8)
                        : const Color(0xFF0C5A32).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? goldAccent.withValues(alpha: 0.5)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: bulletColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                // Expanded indicator icon (chevron up/down)
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: goldAccent,
                  size: 24,
                ),
              ],
            ),
          ),

          // Animate the expansion container smoothly
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: columns[0]),
                    const SizedBox(width: 16),
                    Expanded(child: columns[1]),
                  ],
                ),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailColumn({
    String? header,
    required bool isDark,
    required Color textThemeColor,
    required Color goldAccent,
    Color? silverText,
    Color? valueGreenColor,
    String? mainCategory,
    String? subCategory,
    BuildContext? context,
    required List<Map<String, String>> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column Header in badge style
        if (header != null && header.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF03140A).withValues(alpha: 0.5)
                  : const Color(0xFF0C5A32).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              header,
              style: TextStyle(
                color: goldAccent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Key-Value rows with structured background card and count badges
        ...items.map((item) {
          return GestureDetector(
            onTap: () {
              if (context != null &&
                  mainCategory != null &&
                  silverText != null &&
                  valueGreenColor != null) {
                final targetName = item['name']!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryPersonnelListScreen(
                      categoryName: targetName,
                      isDark: isDark,
                      textThemeColor: textThemeColor,
                      silverText: silverText,
                      goldAccent: goldAccent,
                      valueGreenColor: valueGreenColor,
                      getPersonStatus: (p) {
                        final status = PersonnelDataManager().getStatus(
                          p['armyNo'] ?? '',
                        );
                        if (subCategory != null) {
                          if (status.category == mainCategory &&
                              status.subcategory == subCategory) {
                            return '';
                          }
                          return '';
                        } else {
                          if (status.category == mainCategory) {
                            return status.subcategory ?? '';
                          }
                          return '';
                        }
                      },
                    ),
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF03140A).withValues(alpha: 0.45)
                    : const Color(0xFF0C5A32).withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? goldAccent.withValues(alpha: 0.15)
                      : const Color(0xFF0C5A32).withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_right_outlined,
                          color: goldAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item['name']!,
                            style: TextStyle(
                              color: textThemeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0C5A32).withValues(alpha: 0.3)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['val']!,
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNominalRollTab(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final filteredList = nominalRollList.where((person) {
      // 1. Division Filter (FIGHTING / NON FIGHTING / Subcategories)
      if (_selectedDivision != 'All') {
        final selectedDiv = _selectedDivision.trim().toUpperCase();
        final isFighting = _isFighting(person);

        if (selectedDiv == 'FIGHTING') {
          if (!isFighting) return false;
        } else if (selectedDiv == 'NON FIGHTING') {
          if (isFighting) return false;
        } else {
          final trade = _getTrade(person);
          if (trade.toUpperCase() != selectedDiv) return false;
          if (isFighting) return false;
        }
      }

      // 2. Battery Filter
      if (_selectedBattery != 'All') {
        final bty = _getBattery(person);
        if (bty != _selectedBattery) return false;
      }

      // 3. Rank Filter (Hierarchical support)
      if (_selectedRankCategory != 'All') {
        final selectedRank = _selectedRankCategory.trim();
        final subcat = _getRankSubcategory(
          person['rank'] ?? '',
          person['name'] ?? '',
        );
        final cat = _getRankCategory(
          person['rank'] ?? '',
          person['name'] ?? '',
        );

        if (selectedRank == 'Officers') {
          if (cat != 'OFFICERS') return false;
        } else if (selectedRank == 'JCOs') {
          if (cat != 'JCOs') return false;
        } else if (selectedRank == 'Soldiers' ||
            selectedRank == 'Sldrs' ||
            selectedRank == 'SLDRS') {
          if (cat != 'SLDRS') return false;
        } else {
          if (subcat.toLowerCase() != selectedRank.toLowerCase()) return false;
        }
      }

      // 4. Trade Filter
      if (_selectedTrade != 'All') {
        final trade = _getTrade(person);
        if (trade != _selectedTrade) return false;
      }

      if (_rollSearchQuery.isEmpty) return true;

      final name = (person['name'] ?? '').toLowerCase();
      final armyNo = (person['armyNo'] ?? '').toLowerCase();
      final rank = (person['rank'] ?? '').toLowerCase();
      final cl = (person['cl'] ?? '').toLowerCase();
      final remarks = (person['remarks'] ?? '').toLowerCase();

      return name.contains(_rollSearchQuery) ||
          armyNo.contains(_rollSearchQuery) ||
          rank.contains(_rollSearchQuery) ||
          cl.contains(_rollSearchQuery) ||
          remarks.contains(_rollSearchQuery);
    }).toList();

    filteredList.sort((a, b) {
      final btyA = _getBattery(a);
      final btyB = _getBattery(b);
      if (btyA == btyB) return 0;
      if (btyA == 'P Bty') return -1;
      if (btyB == 'P Bty') return 1;
      return btyA.compareTo(btyB);
    });

    final List<String> divisions = [
      'All',
      'FIGHTING',
      'NON FIGHTING',
      '  Clk',
      '  Ck',
      '  Civ',
      '  LAD',
      '  NCB',
      '  S/W',
      '  Engr',
      '  N/A',
    ];

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 80.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.15)
                      : const Color(0xFF0C5A32).withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: TextFormField(
              controller: _rollSearchController,
              style: TextStyle(color: textThemeColor, fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: goldAccent, size: 20),
                suffixIcon: _rollSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: silverText, size: 18),
                        onPressed: () {
                          _rollSearchController.clear();
                        },
                      )
                    : null,
                hintText: 'Search by Army No, Rank, or Name...',
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : const Color(0xFF0C5A32).withValues(alpha: 0.45),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0C5A32).withValues(alpha: 0.05)
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? goldAccent.withValues(alpha: 0.25)
                        : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: goldAccent, width: 1.2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Scrollable Row of Dropdown Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: _buildDropdownFilter(
                  label: 'Division',
                  value: _selectedDivision,
                  items: divisions,
                  isDark: isDark,
                  goldAccent: goldAccent,
                  textThemeColor: textThemeColor,
                  onChanged: (val) {
                    setState(() {
                      _selectedDivision = val ?? 'All';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: _buildDropdownFilter(
                  label: 'Battery',
                  value: _selectedBattery,
                  items: _batteriesList,
                  isDark: isDark,
                  goldAccent: goldAccent,
                  textThemeColor: textThemeColor,
                  onChanged: (val) {
                    setState(() {
                      _selectedBattery = val ?? 'All';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: _buildDropdownFilter(
                  label: 'Rank',
                  value: _selectedRankCategory,
                  items: _ranksList,
                  isDark: isDark,
                  goldAccent: goldAccent,
                  textThemeColor: textThemeColor,
                  onChanged: (val) {
                    setState(() {
                      _selectedRankCategory = val ?? 'All';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: _buildDropdownFilter(
                  label: 'Trade',
                  value: _selectedTrade,
                  items: _tradesList,
                  isDark: isDark,
                  goldAccent: goldAccent,
                  textThemeColor: textThemeColor,
                  onChanged: (val) {
                    setState(() {
                      _selectedTrade = val ?? 'All';
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing: ${filteredList.length} of ${nominalRollList.length} Personnel',
                style: TextStyle(
                  color: silverText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_selectedDivision != 'All' ||
                  _selectedBattery != 'All' ||
                  _selectedRankCategory != 'All' ||
                  _selectedTrade != 'All' ||
                  _rollSearchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDivision = 'All';
                      _selectedBattery = 'All';
                      _selectedRankCategory = 'All';
                      _selectedTrade = 'All';
                      _rollSearchController.clear();
                    });
                  },
                  child: Text(
                    'Clear Filters',
                    style: TextStyle(
                      color: goldAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 48,
                        color: silverText.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Personnel Found',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 20.0,
                    bottom: 20.0,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final person = filteredList[index];
                    final armyNo = person['armyNo'] ?? '';
                    final rank = person['rank'] ?? '';
                    final name = person['name'] ?? '';
                    final cl = person['cl'] ?? '';
                    final remarks = person['remarks'] ?? '';
                    final category = person['category'] ?? '';

                    final status = _getPersonStatus(person);
                    final isFighting = _isFighting(person);
                    final statusColor =
                        (status == 'Present' ||
                            status == 'Working' ||
                            status == 'Aval')
                        ? valueGreenColor
                        : (status == 'Leave' ||
                              status == 'OSL/Pris' ||
                              status.toLowerCase().contains('sick') ||
                              status.toLowerCase().contains('cmh'))
                        ? Colors.redAccent
                        : goldAccent;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PersonnelIdCardScreen(
                              person: person,
                              isDark: isDark,
                              textThemeColor: textThemeColor,
                              silverText: silverText,
                              goldAccent: goldAccent,
                              valueGreenColor: valueGreenColor,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0C5A32).withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? goldAccent.withValues(alpha: 0.25)
                                : const Color(
                                    0xFF0C5A32,
                                  ).withValues(alpha: 0.15),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.12)
                                  : const Color(
                                      0xFF0C5A32,
                                    ).withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar circle with rank initials and status dot indicator
                                Stack(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: goldAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: goldAccent.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: _buildAvatarImage(person['avatar'] ?? ''),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 1,
                                      bottom: 1,
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF03140A)
                                                : Colors.white,
                                            width: 2.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                // Middle details (Name, Army No, Bty)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$rank $name',
                                        style: TextStyle(
                                          color: textThemeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF03140A)
                                                  : const Color(0xFFE8F5EE),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              armyNo,
                                              style: TextStyle(
                                                color: valueGreenColor,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          // Battery color chip
                                          Builder(
                                            builder: (context) {
                                              final bty = _getBattery(person);
                                              final btyColor = _getBatteryColor(
                                                bty,
                                              );
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: btyColor.withValues(
                                                    alpha: 0.13,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  border: Border.all(
                                                    color: btyColor.withValues(
                                                      alpha: 0.5,
                                                    ),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  bty,
                                                  style: TextStyle(
                                                    color: btyColor,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          Text(
                                            'Cl: $cl',
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
                                const SizedBox(width: 8),
                                // Right Side metadata (Status badge and category indicator)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (_isRollEditMode)
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_note_rounded,
                                          color: goldAccent,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _showPersonFormDialog(
                                            context,
                                            personToEdit: person,
                                            isDark: isDark,
                                            textThemeColor: textThemeColor,
                                            silverText: silverText,
                                            goldAccent: goldAccent,
                                            valueGreenColor: valueGreenColor,
                                          );
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                      ),
                                    if (_isRollDeleteMode)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _showDeletePersonConfirmDialog(
                                            context,
                                            person,
                                            isDark,
                                            goldAccent,
                                            silverText,
                                          );
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(
                                                0xFF0C5A32,
                                              ).withValues(alpha: 0.05)
                                            : const Color(
                                                0xFF0C5A32,
                                              ).withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isFighting
                                              ? valueGreenColor.withValues(
                                                  alpha: 0.3,
                                                )
                                              : Colors.orange.withValues(
                                                  alpha: 0.3,
                                                ),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          color: isFighting
                                              ? valueGreenColor
                                              : Colors.orange,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (remarks.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(
                                          0xFF03140A,
                                        ).withValues(alpha: 0.4)
                                      : const Color(
                                          0xFF0C5A32,
                                        ).withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: goldAccent.withValues(alpha: 0.15),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.assignment_ind_rounded,
                                      color: goldAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        remarks,
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFD0D0D0)
                                              : const Color(0xFF3B4D41),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  bool _isFighting(Map<String, String> person) {
    if (person['isFighting'] == 'false') return false;
    if (person['isFighting'] == 'true') return true;
    final category = (person['category'] ?? '').toLowerCase();
    final name = (person['name'] ?? '').toLowerCase();
    final rank = (person['rank'] ?? '').toLowerCase();
    final combined = '$rank $name'.toLowerCase();

    if (category == 'clks' ||
        category == 'c/us' ||
        category == 'sws' ||
        category == 's/ws' ||
        category == 'ncbs' ||
        category == 'civs' ||
        category == 'lads') {
      return false;
    }

    if (combined.contains('clk') ||
        combined.contains('ck ') ||
        combined.contains('ck(') ||
        combined.contains('c/u') ||
        combined.contains('c/m') ||
        combined.contains('engr') ||
        combined.contains('n/a') ||
        combined.contains('lad') ||
        combined.contains('civ') ||
        combined.contains('ncb') ||
        combined.contains('sw') ||
        combined.contains('s/w')) {
      return false;
    }

    return true;
  }

  String _getRankSubcategory(String rank, String name) {
    final r = rank.trim().toLowerCase();

    // 1. Officers
    if (r == 'lt col' || r.startsWith('lt col') || r.contains('lt col')) {
      return 'Lt Col';
    }
    if (r == 'maj' || r.startsWith('maj') || r.contains('maj')) return 'Maj';
    if (r == 'capt' || r.startsWith('capt') || r.contains('capt')) {
      return 'Capt';
    }
    if (r == '2/lt' || r == '2-lt' || r == '2/ lt' || r.contains('2/lt')) {
      return '2/Lt';
    }
    if (r == 'lt' || r == 'lieutenant') return 'Lt';

    // 2. JCOs
    if (r == 'sm' || r == 'subedar major') return 'SM';
    if (r == 'n/sub' ||
        r == 'n-sub' ||
        r == 'naib subedar' ||
        r.contains('n/sub')) {
      return 'N/Sub';
    }
    if (r == 'sub' || r == 'subedar') return 'Sub';

    // 3. Soldiers
    if (r.contains('hav') ||
        r.contains('bqmh') ||
        r.contains('rqmh') ||
        r == 'havildar') {
      return 'Hav';
    }
    if (r == 'lhav' ||
        r == 'lhv' ||
        r == 'lance havildar' ||
        r.contains('lhav') ||
        r.contains('lhv')) {
      return 'Lhav';
    }
    if (r == 'lnk' ||
        r == 'l/nk' ||
        r == 'lance naik' ||
        r.contains('lnk') ||
        r.contains('l/nk')) {
      return 'Lnk';
    }
    if (r == 'nk' || r == 'naik' || r == 'nco' || r.contains('nk')) {
      return 'Nk';
    }

    return 'Sep';
  }

  String _getRankCategory(String rank, String name) {
    final sub = _getRankSubcategory(rank, name);
    if (['Lt Col', 'Maj', 'Capt', 'Lt', '2/Lt'].contains(sub)) {
      return 'OFFICERS';
    }
    if (['SM', 'Sub', 'N/Sub'].contains(sub)) {
      return 'JCOs';
    }
    return 'SLDRS';
  }

  String _getTrade(Map<String, String> person) {
    final category = (person['category'] ?? '').toLowerCase();
    final rank = (person['rank'] ?? '').toLowerCase();
    final name = (person['name'] ?? '').toLowerCase();
    final combined = '$rank $name'.toLowerCase();

    if (category == 'clks' || combined.contains('clk')) return 'Clk';
    if (category == 'ncbs' || combined.contains('ncb')) return 'NCB';
    if (category == 'sws' ||
        combined.contains('sw') ||
        combined.contains('s/w')) {
      return 'S/W';
    }
    if (category == 'c/us' ||
        combined.contains('ck') ||
        combined.contains('c/u') ||
        combined.contains('c/m')) {
      return 'Ck';
    }
    if (category == 'civs' || combined.contains('civ')) return 'Civ';
    if (category == 'lads' || combined.contains('lad')) return 'LAD';

    if (category == 'jcos') {
      if (combined.contains('gnr')) return 'Gnr';
      if (combined.contains('ta')) return 'TA';
      if (combined.contains('ocu')) return 'OCU';
      if (combined.contains('dmt')) return 'DMT';
      if (combined.contains('dsv')) return 'DSV';
      if (combined.contains('svy') || combined.contains('sry')) return 'Svy';
    }
    if (category == 'svys' ||
        combined.contains('svy') ||
        combined.contains('sry')) {
      return 'Svy';
    }
    if (category == 'tas' || combined.contains('ta')) return 'TA';
    if (category == 'ocsu' || combined.contains('ocu')) return 'OCU';
    if (category == 'dsvs' || combined.contains('dsv')) return 'DSV';
    if (category == 'dmts' || combined.contains('dmt')) return 'DMT';
    if (category == 'gnrs' || combined.contains('gnr')) return 'Gnr';

    return 'Gnr';
  }

  String _getBattery(Map<String, String> person) {
    if (person['battery'] != null && person['battery']!.isNotEmpty) {
      return person['battery']!;
    }
    final armyNo = person['armyNo'] ?? '';
    if (armyNo == 'NYA' || armyNo.isEmpty) {
      return 'HQ Bty';
    }
    final cleanNo = armyNo.replaceAll(RegExp(r'\D'), '');
    if (cleanNo.isEmpty) return 'HQ Bty';
    final lastDigit = int.tryParse(cleanNo[cleanNo.length - 1]) ?? 0;
    if (lastDigit == 0 || lastDigit == 4) return 'HQ Bty';
    if (lastDigit == 1 || lastDigit == 5) return 'P Bty';
    if (lastDigit == 2 || lastDigit == 6 || lastDigit == 8) return 'Q Bty';
    return 'R Bty';
  }

  String _getCity(Map<String, String> person) {
    final armyNo = person['armyNo'] ?? '';
    final cleanNo = armyNo.replaceAll(RegExp(r'\D'), '');
    final id = int.tryParse(cleanNo) ?? 0;
    final cities = [
      'Rawalpindi',
      'Lahore',
      'Karachi',
      'Peshawar',
      'Quetta',
      'Multan',
      'Faisalabad',
      'Islamabad',
      'Gujranwala',
      'Sialkot',
    ];
    return cities[id % cities.length];
  }

  /// Returns the distinct color for each battery.
  Color _getBatteryColor(String bty) {
    switch (bty) {
      case 'HQ Bty':
        return const Color(0xFFE53935); // Red - Headquarter Battery
      case 'P Bty':
        return const Color(0xFF9E9E9E); // Light Gray - Papa Battery
      case 'Q Bty':
        return const Color(0xFFFF9800); // Light Orange - Quebec Battery
      case 'R Bty':
        return const Color(0xFF4CAF50); // Light Green - Romeo Battery
      default:
        return const Color(0xFFE53935);
    }
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required bool isDark,
    required Color goldAccent,
    required Color textThemeColor,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF03140A) : Colors.white,
      style: TextStyle(
        color: textThemeColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      icon: Icon(Icons.unfold_more_rounded, color: goldAccent, size: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF0C5A32).withValues(alpha: 0.05)
            : Colors.white,
        contentPadding: const EdgeInsets.only(
          left: 6,
          right: 0,
          top: 10,
          bottom: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? goldAccent.withValues(alpha: 0.25)
                : const Color(0xFF0C5A32).withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: goldAccent, width: 1.2),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: TextStyle(color: textThemeColor, fontSize: 12),
          ),
        );
      }).toList(),
      selectedItemBuilder: (BuildContext context) {
        return items.map<Widget>((item) {
          final displayText = (item == 'All') ? label : item;
          return Text(
            displayText,
            style: TextStyle(
              color: isDark ? const Color(0xFFE5E5E5) : const Color(0xFF3B4D41),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }).toList();
      },
      onChanged: onChanged,
    );
  }

  String _getPersonStatus(Map<String, String> person) {
    return PersonnelDataManager().getStatus(person['armyNo'] ?? '').category;
  }

  Widget _buildAnalysisTab(
    BuildContext context,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
    Color valueGreenColor,
  ) {
    final filteredPersonnel = nominalRollList.where((person) {
      if (_analysisMode == 'Battery' &&
          !_analysisFilterBattery.contains('All') &&
          _analysisFilterBattery.isNotEmpty) {
        if (!_analysisFilterBattery.contains(_getBattery(person))) return false;
      }
      if (_analysisMode == 'Trade' &&
          !_analysisFilterTrade.contains('All') &&
          _analysisFilterTrade.isNotEmpty) {
        if (!_analysisFilterTrade.contains(_getTrade(person))) return false;
      }
      if (_analysisMode == 'Rank' &&
          !_analysisFilterRank.contains('All') &&
          _analysisFilterRank.isNotEmpty) {
        final subcat = _getRankSubcategory(
          person['rank'] ?? '',
          person['name'] ?? '',
        );
        final cat = _getRankCategory(
          person['rank'] ?? '',
          person['name'] ?? '',
        );

        bool matchesAny = false;
        for (final selectedRankRaw in _analysisFilterRank) {
          final selectedRank = selectedRankRaw.trim();
          if (selectedRank == 'Officers') {
            if (cat == 'OFFICERS') {
              matchesAny = true;
              break;
            }
          } else if (selectedRank == 'JCOs') {
            if (cat == 'JCOs') {
              matchesAny = true;
              break;
            }
          } else if (selectedRank == 'Soldiers' ||
              selectedRank == 'Sldrs' ||
              selectedRank == 'SLDRS' ||
              selectedRank == 'SOLDIERS') {
            if (cat == 'SLDRS' || cat == 'SOLDIERS') {
              matchesAny = true;
              break;
            }
          } else {
            if (subcat.toLowerCase() == selectedRank.toLowerCase()) {
              matchesAny = true;
              break;
            }
          }
        }
        if (!matchesAny) return false;
      }
      return true;
    }).toList();
    // ──────────────────────────────────────────────────────────────────────────

    int totalStrength = filteredPersonnel.length;
    int fightingStrength = 0;
    int nonFightingStrength = 0;

    Map<String, int> officerRanks = {};
    Map<String, int> jcoTrades = {};
    Map<String, int> sldrTrades = {};

    Map<String, int> nonFightingTrades = {
      'Clk': 0,
      'Ck': 0,
      'Engr': 0,
      'N/A': 0,
      'LAD': 0,
      'NCB': 0,
      'S/W': 0,
      'Civ': 0,
    };

    Map<String, Map<String, int>> nonFightingTradeRanks = {
      'Clk': {},
      'Ck': {},
      'Engr': {},
      'N/A': {},
      'LAD': {},
      'NCB': {},
      'S/W': {},
      'Civ': {},
    };

    Map<String, int> fightingJcoRanks = {};
    Map<String, int> fightingSldrRanks = {};

    // Battery Stats mapping
    Map<String, Map<String, int>> batteryStats = {
      'HQ Bty': {
        'total': 0,
        'officers': 0,
        'jcos': 0,
        'sldrs': 0,
        'nonFighting': 0,
      },
      'P Bty': {
        'total': 0,
        'officers': 0,
        'jcos': 0,
        'sldrs': 0,
        'nonFighting': 0,
      },
      'Q Bty': {
        'total': 0,
        'officers': 0,
        'jcos': 0,
        'sldrs': 0,
        'nonFighting': 0,
      },
      'R Bty': {
        'total': 0,
        'officers': 0,
        'jcos': 0,
        'sldrs': 0,
        'nonFighting': 0,
      },
    };

    for (var person in filteredPersonnel) {
      final isFighting = _isFighting(person);
      final bty = _getBattery(person);
      final rankCat = _getRankCategory(
        person['rank'] ?? '',
        person['name'] ?? '',
      );

      if (batteryStats.containsKey(bty)) {
        batteryStats[bty]!['total'] = batteryStats[bty]!['total']! + 1;
        if (!isFighting) {
          batteryStats[bty]!['nonFighting'] =
              batteryStats[bty]!['nonFighting']! + 1;
        } else {
          if (rankCat == 'OFFICERS') {
            batteryStats[bty]!['officers'] =
                batteryStats[bty]!['officers']! + 1;
          } else if (rankCat == 'JCOs') {
            batteryStats[bty]!['jcos'] = batteryStats[bty]!['jcos']! + 1;
          } else {
            batteryStats[bty]!['sldrs'] = batteryStats[bty]!['sldrs']! + 1;
          }
        }
      }

      if (isFighting) {
        fightingStrength++;
        final trade = _getTrade(person);
        final rank = person['rank'] ?? 'Gnr';

        if (rankCat == 'OFFICERS') {
          officerRanks[rank] = (officerRanks[rank] ?? 0) + 1;
        } else if (rankCat == 'JCOs') {
          jcoTrades[trade] = (jcoTrades[trade] ?? 0) + 1;
          fightingJcoRanks[rank] = (fightingJcoRanks[rank] ?? 0) + 1;
        } else {
          sldrTrades[trade] = (sldrTrades[trade] ?? 0) + 1;
          fightingSldrRanks[rank] = (fightingSldrRanks[rank] ?? 0) + 1;
        }
      } else {
        nonFightingStrength++;
        final trade = _getTrade(person);
        final rank = person['rank'] ?? 'Sep';
        if (nonFightingTrades.containsKey(trade)) {
          nonFightingTrades[trade] = nonFightingTrades[trade]! + 1;
          nonFightingTradeRanks[trade]![rank] =
              (nonFightingTradeRanks[trade]![rank] ?? 0) + 1;
        }
      }
    }

    Map<String, int> fightingStatusCounts = {};
    Map<String, int> nonFightingStatusCounts = {};

    for (var person in filteredPersonnel) {
      final isFighting = _isFighting(person);
      final status = _getPersonStatus(person);
      if (isFighting) {
        fightingStatusCounts[status] = (fightingStatusCounts[status] ?? 0) + 1;
      } else {
        nonFightingStatusCounts[status] =
            (nonFightingStatusCounts[status] ?? 0) + 1;
      }
    }

    final List<String> paradeCategories = [
      'Present',
      'Leave',
      'Att',
      'Aval',
      'Courses',
      'OSL/Pris',
      'Sta Gds',
      'Unit Gds',
      'CMH/Sick',
      'Regt Emp',
      'Trg',
      'Sports',
      'Aslt Course',
      'DIDO',
      'Working',
      'Prot',
      'Ex/Cl',
      'U/D',
    ];

    // Dropdown option lists
    final List<String> batteryOptions = [
      'All',
      'HQ Bty',
      'P Bty',
      'Q Bty',
      'R Bty',
    ];
    final List<String> tradeOptions = [
      'All',
      'Gnr',
      'TA',
      'OCU',
      'DMT',
      'DSV',
      'Svy',
      'Clk',
      'Ck',
      'NCB',
      'S/W',
      'Engr',
      'N/A',
      'LAD',
      'Civ',
    ];
    final List<String> rankOptions = [
      'All',
      'Officers',
      '  Lt Col',
      '  Maj',
      '  Capt',
      '  Lt',
      '  2/Lt',
      'JCOs',
      '  SM',
      '  Sub',
      '  N/Sub',
      'Soldiers',
      '  Hav',
      '  Lhav',
      '  Nk',
      '  Lnk',
      '  Sep',
    ];

    final List<String> currentFilterValue = _analysisMode == 'Battery'
        ? _analysisFilterBattery
        : _analysisMode == 'Trade'
        ? _analysisFilterTrade
        : _analysisFilterRank;
    final bool isFiltered = currentFilterValue.isNotEmpty && !currentFilterValue.contains('All');
    final String filterLabel = isFiltered
        ? currentFilterValue.join(', ')
        : 'All ${_analysisMode}s';

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 80.0),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF03140A).withValues(alpha: 0.8)
                  : const Color(0xFF0C5A32).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? goldAccent.withValues(alpha: 0.3)
                    : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildAnalysisModeTab(
                    'Rank',
                    textThemeColor,
                    goldAccent,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildAnalysisModeTab(
                    'Trade',
                    textThemeColor,
                    goldAccent,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildAnalysisModeTab(
                    'Battery',
                    textThemeColor,
                    goldAccent,
                    isDark,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Analysis Filter Dropdowns ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0A2214).withValues(alpha: 0.6)
                  : const Color(0xFFF0F8F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? goldAccent.withValues(alpha: 0.18)
                    : const Color(0xFF0C5A32).withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: 13,
                      color: goldAccent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'FILTER: $filterLabel',
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const Spacer(),
                    if (isFiltered)
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_analysisMode == 'Battery') {
                            _analysisFilterBattery = ['All'];
                          }
                          if (_analysisMode == 'Trade') {
                            _analysisFilterTrade = ['All'];
                          }
                          if (_analysisMode == 'Rank') {
                            _analysisFilterRank = ['All'];
                          }
                        }),
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_analysisMode == 'Battery')
                  _buildAnalysisMultiSelectDropdown(
                    label: 'Select Battery',
                    selectedValues: _analysisFilterBattery,
                    items: batteryOptions,
                    isDark: isDark,
                    goldAccent: goldAccent,
                    textThemeColor: textThemeColor,
                    onChanged: (v) =>
                        setState(() => _analysisFilterBattery = v),
                  )
                else if (_analysisMode == 'Trade')
                  _buildAnalysisMultiSelectDropdown(
                    label: 'Select Trade',
                    selectedValues: _analysisFilterTrade,
                    items: tradeOptions,
                    isDark: isDark,
                    goldAccent: goldAccent,
                    textThemeColor: textThemeColor,
                    onChanged: (v) =>
                        setState(() => _analysisFilterTrade = v),
                  )
                else
                  _buildAnalysisMultiSelectDropdown(
                    label: 'Select Rank',
                    selectedValues: _analysisFilterRank,
                    items: rankOptions,
                    isDark: isDark,
                    goldAccent: goldAccent,
                    textThemeColor: textThemeColor,
                    onChanged: (v) =>
                        setState(() => _analysisFilterRank = v),
                  ),
              ],
            ),
          ),
        ),

        // ──────────────────────────────────────────────────────────────────
        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0C5A32).withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? goldAccent.withValues(alpha: 0.35)
                    : const Color(0xFF0C5A32).withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.15)
                      : const Color(0xFF0C5A32).withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAnalysisSummaryItem(
                  label: _analysisMode == 'Trade'
                      ? 'Trade Total'
                      : (_analysisMode == 'Rank' ? 'Rank Total' : 'Bty Total'),
                  value: '$totalStrength',
                  isDark: isDark,
                  goldAccent: goldAccent,
                  textThemeColor: textThemeColor,
                ),
                _buildAnalysisSummaryItem(
                  label: 'Fighting',
                  value: '$fightingStrength',
                  isDark: isDark,
                  goldAccent: goldAccent,
                  textThemeColor: textThemeColor,
                ),
                _buildAnalysisSummaryItem(
                  label: 'Non Fighting',
                  value: '$nonFightingStrength',
                  isDark: isDark,
                  goldAccent: goldAccent,
                  textThemeColor: textThemeColor,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_analysisMode == 'Battery') ...[
                  // Battery cards — show only selected battery full-width, or all 4 in 2x2 grid
                  if (_analysisFilterBattery.contains('All') || _analysisFilterBattery.isEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildBatteryAnalysisCard(
                            name: 'HQ Battery',
                            stats: batteryStats['HQ Bty'] ?? {},
                            isDark: isDark,
                            batteryColor: _getBatteryColor('HQ Bty'),
                            textThemeColor: textThemeColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildBatteryAnalysisCard(
                            name: 'P Battery',
                            stats: batteryStats['P Bty'] ?? {},
                            isDark: isDark,
                            batteryColor: _getBatteryColor('P Bty'),
                            textThemeColor: textThemeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBatteryAnalysisCard(
                            name: 'Q Battery',
                            stats: batteryStats['Q Bty'] ?? {},
                            isDark: isDark,
                            batteryColor: _getBatteryColor('Q Bty'),
                            textThemeColor: textThemeColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildBatteryAnalysisCard(
                            name: 'R Battery',
                            stats: batteryStats['R Bty'] ?? {},
                            isDark: isDark,
                            batteryColor: _getBatteryColor('R Bty'),
                            textThemeColor: textThemeColor,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    ..._analysisFilterBattery.map((bty) {
                      final displayName = bty == 'HQ Bty'
                          ? 'HQ Battery'
                          : bty == 'P Bty'
                              ? 'P Battery'
                              : bty == 'Q Bty'
                                  ? 'Q Battery'
                                  : 'R Battery';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildBatteryAnalysisCard(
                            name: displayName,
                            stats: batteryStats[bty] ?? {},
                            isDark: isDark,
                            batteryColor: _getBatteryColor(bty),
                            textThemeColor: textThemeColor,
                          ),
                        ),
                      );
                    }),
                  ],
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(
                                    0xFF0C5A32,
                                  ).withValues(alpha: 0.04)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? goldAccent.withValues(alpha: 0.15)
                                  : const Color(
                                      0xFF0C5A32,
                                    ).withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FIGHTING',
                                style: TextStyle(
                                  color: goldAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Divider(height: 12, thickness: 0.5),

                              _buildSectionHeader('Officers'),
                              if (_analysisMode == 'Trade') ...[
                                _buildBulletItem(
                                  'Lt Col, Maj, Capt, Lt, 2/Lt',
                                  isDark,
                                ),
                              ] else ...[
                                ...officerRanks.entries
                                    .where((e) => e.value > 0)
                                    .map(
                                      (e) => _buildBulletItem(
                                        '${e.key} - ${e.value}',
                                        isDark,
                                      ),
                                    ),
                              ],

                              const SizedBox(height: 10),

                              _buildSectionHeader('JCOs'),
                              if (_analysisMode == 'Trade') ...[
                                ...jcoTrades.entries
                                    .where((e) => e.value > 0)
                                    .map(
                                      (e) => _buildBulletItem(
                                        '${e.key} - ${e.value}',
                                        isDark,
                                      ),
                                    ),
                              ] else ...[
                                ...fightingJcoRanks.entries
                                    .where((e) => e.value > 0)
                                    .map(
                                      (e) => _buildBulletItem(
                                        '${e.key} - ${e.value}',
                                        isDark,
                                      ),
                                    ),
                              ],

                              const SizedBox(height: 10),

                              _buildSectionHeader('Sldrs'),
                              if (_analysisMode == 'Trade') ...[
                                ...sldrTrades.entries
                                    .where((e) => e.value > 0)
                                    .map(
                                      (e) => _buildBulletItem(
                                        '${e.key} - ${e.value}',
                                        isDark,
                                      ),
                                    ),
                              ] else ...[
                                ...fightingSldrRanks.entries
                                    .where((e) => e.value > 0)
                                    .map(
                                      (e) => _buildBulletItem(
                                        '${e.key} - ${e.value}',
                                        isDark,
                                      ),
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(
                                    0xFF0C5A32,
                                  ).withValues(alpha: 0.04)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? goldAccent.withValues(alpha: 0.15)
                                  : const Color(
                                      0xFF0C5A32,
                                    ).withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NON FIGHTING',
                                style: TextStyle(
                                  color: goldAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Divider(height: 12, thickness: 0.5),

                              ...nonFightingTrades.entries
                                  .where((e) => e.value > 0)
                                  .map((e) {
                                    final trade = e.key;
                                    final count = e.value;
                                    final subRanks =
                                        nonFightingTradeRanks[trade] ?? {};

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionHeader(
                                            '$trade - $count',
                                          ),
                                          if (_analysisMode == 'Rank' &&
                                              count > 0)
                                            ...subRanks.entries
                                                .where((r) => r.value > 0)
                                                .map(
                                                  (r) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 6.0,
                                                        ),
                                                    child: Text(
                                                      '• ${r.key} - ${r.value}',
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? const Color(
                                                                0xFFB0B0B0,
                                                              )
                                                            : const Color(
                                                                0xFF4A4A4A,
                                                              ),
                                                        fontSize: 10.5,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    );
                                  }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                _buildParadeStatePanel(
                  title: 'Offrs/JCOs/Sldrs',
                  categories: paradeCategories,
                  counts: fightingStatusCounts,
                  isDark: isDark,
                  goldAccent: goldAccent,
                  isFightingGroup: true,
                  baseList: filteredPersonnel,
                  initialBattery: _analysisMode == 'Battery'
                      ? (_analysisFilterBattery.contains('All') ? 'All' : _analysisFilterBattery.join(', '))
                      : 'All',
                  initialTrade: _analysisMode == 'Trade'
                      ? (_analysisFilterTrade.contains('All') ? 'All' : _analysisFilterTrade.join(', '))
                      : 'All',
                  initialRank: _analysisMode == 'Rank'
                      ? (_analysisFilterRank.contains('All') ? 'All' : _analysisFilterRank.join(', '))
                      : 'All',
                ),

                const SizedBox(height: 16),

                _buildParadeStatePanel(
                  title: 'Clk/Ck/NCBs/Engrs, etc.',
                  categories: paradeCategories,
                  counts: nonFightingStatusCounts,
                  isDark: isDark,
                  goldAccent: goldAccent,
                  isFightingGroup: false,
                  baseList: filteredPersonnel,
                  initialBattery: _analysisMode == 'Battery'
                      ? (_analysisFilterBattery.contains('All') ? 'All' : _analysisFilterBattery.join(', '))
                      : 'All',
                  initialTrade: _analysisMode == 'Trade'
                      ? (_analysisFilterTrade.contains('All') ? 'All' : _analysisFilterTrade.join(', '))
                      : 'All',
                  initialRank: _analysisMode == 'Rank'
                      ? (_analysisFilterRank.contains('All') ? 'All' : _analysisFilterRank.join(', '))
                      : 'All',
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisSummaryItem({
    required String label,
    required String value,
    required bool isDark,
    required Color goldAccent,
    required Color textThemeColor,
  }) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : const Color(0xFF0C5A32).withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: goldAccent,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C5A32).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFCD9B2D),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildBulletItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 6.0, top: 2.0),
      child: Text(
        '• $text',
        style: TextStyle(
          color: isDark ? const Color(0xFFE5E5E5) : const Color(0xFF3B4D41),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAnalysisModeTab(
    String mode,
    Color textThemeColor,
    Color goldAccent,
    bool isDark,
  ) {
    final isSelected = _analysisMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _analysisMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [goldAccent, goldAccent.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: goldAccent.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '$mode Analysis',
            style: TextStyle(
              color: isSelected
                  ? (isDark ? const Color(0xFF03140A) : Colors.white)
                  : textThemeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisMultiSelectDropdown({
    required String label,
    required List<String> selectedValues,
    required List<String> items,
    required bool isDark,
    required Color goldAccent,
    required Color textThemeColor,
    required ValueChanged<List<String>> onChanged,
  }) {
    final String displayText = (selectedValues.isEmpty || selectedValues.contains('All'))
        ? 'All'
        : selectedValues.join(', ');

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return _MultiSelectDialog(
              title: label,
              items: items,
              initialSelectedValues: selectedValues,
              isDark: isDark,
              goldAccent: goldAccent,
              textThemeColor: textThemeColor,
              onApply: onChanged,
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0C5A32).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? goldAccent.withValues(alpha: 0.2)
                : const Color(0xFF0C5A32).withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark
                          ? goldAccent.withValues(alpha: 0.7)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayText,
                    style: TextStyle(
                      color: textThemeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: goldAccent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Maps display name (e.g. 'HQ Battery') -> battery key (e.g. 'HQ Bty')
  String _batteryKeyFromName(String displayName) {
    switch (displayName) {
      case 'HQ Battery':
        return 'HQ Bty';
      case 'P Battery':
        return 'P Bty';
      case 'Q Battery':
        return 'Q Bty';
      case 'R Battery':
        return 'R Bty';
      default:
        return 'HQ Bty';
    }
  }

  Widget _buildBatteryAnalysisCard({
    required String name,
    required Map<String, int> stats,
    required bool isDark,
    required Color batteryColor,
    required Color textThemeColor,
  }) {
    final total = stats['total'] ?? 0;
    final officers = stats['officers'] ?? 0;
    final jcos = stats['jcos'] ?? 0;
    final sldrs = stats['sldrs'] ?? 0;
    final nonFighting = stats['nonFighting'] ?? 0;
    final fighting = officers + jcos + sldrs;
    final fightingRatio = total > 0 ? fighting / total : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                BatteryDetailScreen(
                  batteryKey: _batteryKeyFromName(name),
                  batteryName: name,
                  batteryColor: batteryColor,
                  isDarkMode: widget.isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  final tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: Curves.easeInOutCubic));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? batteryColor.withValues(alpha: 0.07)
              : batteryColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: batteryColor.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: batteryColor.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left battery color accent strip
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: batteryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(13),
                      bottomLeft: Radius.circular(13),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row: battery name + strength badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name.toUpperCase(),
                              style: TextStyle(
                                color: batteryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: batteryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: batteryColor.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Str: $total',
                                style: TextStyle(
                                  color: batteryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: 14,
                          thickness: 0.5,
                          color: batteryColor.withValues(alpha: 0.3),
                        ),
                        if (officers > 0)
                          _buildCardDetailRow(
                            'Officers',
                            '$officers',
                            isDark,
                            batteryColor,
                          ),
                        if (jcos > 0)
                          _buildCardDetailRow(
                            'JCOs',
                            '$jcos',
                            isDark,
                            batteryColor,
                          ),
                        if (sldrs > 0)
                          _buildCardDetailRow(
                            'Sldrs',
                            '$sldrs',
                            isDark,
                            batteryColor,
                          ),
                        if (nonFighting > 0)
                          _buildCardDetailRow(
                            'Non-Fighting',
                            '$nonFighting',
                            isDark,
                            batteryColor,
                          ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Fighting Ratio',
                              style: TextStyle(
                                color: textThemeColor.withValues(alpha: 0.5),
                                fontSize: 9.5,
                              ),
                            ),
                            Text(
                              '${(fightingRatio * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: batteryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fightingRatio,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.black.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              batteryColor,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ), // GestureDetector
    );
  }

  Widget _buildCardDetailRow(
    String label,
    String value,
    bool isDark, [
    Color? accentColor,
  ]) {
    final color = accentColor ?? const Color(0xFFCD9B2D);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFB0B0B0)
                      : const Color(0xFF4C5E53),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 0.6,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParadeStatePanel({
    required String title,
    required List<String> categories,
    required Map<String, int> counts,
    required bool isDark,
    required Color goldAccent,
    required bool isFightingGroup,
    required List<Map<String, String>> baseList,
    String initialBattery = 'All',
    String initialTrade = 'All',
    String initialRank = 'All',
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C5A32).withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? goldAccent.withValues(alpha: 0.2)
              : const Color(0xFF0C5A32).withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: goldAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const Divider(height: 16, thickness: 0.5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories.where((cat) => (counts[cat] ?? 0) > 0).map((
              cat,
            ) {
              final count = counts[cat] ?? 0;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryPersonnelListScreen(
                        categoryName: cat,
                        isDark: isDark,
                        textThemeColor: isDark
                            ? Colors.white
                            : const Color(0xFF042011),
                        silverText: isDark
                            ? const Color(0xFFE5E5E5)
                            : const Color(0xFF4A5D52),
                        goldAccent: goldAccent,
                        valueGreenColor: isDark
                            ? const Color(0xFF00FF66)
                            : const Color(0xFF0C5A32),
                        getPersonStatus: _getPersonStatus,
                        filterIsFighting: isFightingGroup,
                        baseList: baseList,
                        initialBattery: initialBattery,
                        initialTrade: initialTrade,
                        initialRank: initialRank,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF03140A).withValues(alpha: 0.8)
                        : const Color(0xFF0C5A32).withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: goldAccent.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '• $cat: ',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFB0B0B0)
                              : const Color(0xFF3B4D41),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$count',
                        style: TextStyle(
                          color: goldAccent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String avatar) {
    if (avatar.isEmpty) {
      return Image.asset(
        'assets/images/profile_avatar.jpg',
        key: const ValueKey('default'),
        fit: BoxFit.cover,
      );
    }
    if (avatar.startsWith('data:image')) {
      try {
        final cleanBase64 = avatar.split(',').last;
        final bytes = base64Decode(cleanBase64);
        return Image.memory(
          bytes,
          key: ValueKey(avatar),
          fit: BoxFit.cover,
        );
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return Image.asset(
          'assets/images/profile_avatar.jpg',
          key: const ValueKey('error'),
          fit: BoxFit.cover,
        );
      }
    }
    if (avatar.startsWith('http')) {
      return Image.network(
        avatar,
        key: ValueKey(avatar),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/profile_avatar.jpg',
            key: const ValueKey('net_error'),
            fit: BoxFit.cover,
          );
        },
      );
    }
    if (avatar.startsWith('assets/')) {
      return Image.asset(
        avatar,
        key: ValueKey(avatar),
        fit: BoxFit.cover,
      );
    }
    return Image.asset(
      'assets/images/profile_avatar.jpg',
      key: ValueKey(avatar),
      fit: BoxFit.cover,
    );
  }

  Future<String?> _pickImageAsBase64() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 200,
        maxHeight: 200,
      );
      if (image == null) return null;

      final bytes = await image.readAsBytes();
      final String base64String = base64Encode(bytes);
      final String mimeType = image.mimeType ?? 'image/jpeg';
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }
}

class CategoryPersonnelListScreen extends StatefulWidget {
  final String categoryName;
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;
  final String Function(Map<String, String>) getPersonStatus;

  /// If non-null, restricts list to fighting (true) or non-fighting (false) personnel.
  final bool? filterIsFighting;

  /// If provided, used as the source list instead of the full nominalRollList.
  /// Pass the already-filtered personnel from the analysis tab so that
  /// tapping a chip (e.g. "Present: 4") shows only those 4 specific people.
  final List<Map<String, String>>? baseList;

  /// Pre-selected filter values (from analysis screen).
  final String initialBattery;
  final String initialTrade;
  final String initialRank;

  const CategoryPersonnelListScreen({
    super.key,
    required this.categoryName,
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
    required this.getPersonStatus,
    this.filterIsFighting,
    this.baseList,
    this.initialBattery = 'All',
    this.initialTrade = 'All',
    this.initialRank = 'All',
  });

  @override
  State<CategoryPersonnelListScreen> createState() =>
      _CategoryPersonnelListScreenState();
}

class _CategoryPersonnelListScreenState
    extends State<CategoryPersonnelListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _selectedDivision = 'All';
  String _selectedBattery = 'All';
  String _selectedRankCategory = 'All';
  String _selectedTrade = 'All';

  List<String> _tradesList = [
    'All',
    'Gnr',
    'TA',
    'OCU',
    'DMT',
    'DSV',
    'Svy',
    'Clk',
    'Ck',
    'Engr',
    'N/A',
    'LAD',
    'NCB',
    'S/W',
    'Civ',
  ];
  List<String> _ranksList = [
    'All',
    'Officers',
    '  Lt Col',
    '  Maj',
    '  Capt',
    '  Lt',
    '  2/Lt',
    'JCOs',
    '  SM',
    '  Sub',
    '  N/Sub',
    'Soldiers',
    '  Hav',
    '  Lhav',
    '  Nk',
    '  Lnk',
    '  Sep',
  ];
  List<String> _batteriesList = ['All', 'HQ Bty', 'P Bty', 'Q Bty', 'R Bty'];

  @override
  void initState() {
    super.initState();
    _selectedBattery = _batteriesList.contains(widget.initialBattery) ? widget.initialBattery : 'All';
    _selectedRankCategory = _ranksList.contains(widget.initialRank) ? widget.initialRank : 'All';
    _selectedTrade = _tradesList.contains(widget.initialTrade) ? widget.initialTrade : 'All';
    _loadDynamicAttributes();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _loadDynamicAttributes() async {
    final trades = await MockDataManager().getTrades();
    final ranks = await MockDataManager().getRanks();
    final batteries = await MockDataManager().getBatteries();
    if (mounted) {
      setState(() {
        _tradesList = trades;
        _ranksList = ranks;
        _batteriesList = batteries;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isFighting(Map<String, String> person) {
    if (person['isFighting'] == 'false') return false;
    if (person['isFighting'] == 'true') return true;
    final cat = person['category'] ?? '';
    if (cat == 'Officers' ||
        cat == 'JCOs' ||
        cat == 'Svys' ||
        cat == 'TAs' ||
        cat == 'OCsU' ||
        cat == 'DSVs' ||
        cat == 'DMTs' ||
        cat == 'Gnrs') {
      return true;
    }
    return false;
  }

  String _getRankSubcategory(String rank, String name) {
    final r = rank.trim().toLowerCase();

    // 1. Officers
    if (r == 'lt col' || r.startsWith('lt col') || r.contains('lt col')) {
      return 'Lt Col';
    }
    if (r == 'maj' || r.startsWith('maj') || r.contains('maj')) return 'Maj';
    if (r == 'capt' || r.startsWith('capt') || r.contains('capt')) {
      return 'Capt';
    }
    if (r == '2/lt' || r == '2-lt' || r == '2/ lt' || r.contains('2/lt')) {
      return '2/Lt';
    }
    if (r == 'lt' || r == 'lieutenant') return 'Lt';

    // 2. JCOs
    if (r == 'sm' || r == 'subedar major') return 'SM';
    if (r == 'n/sub' ||
        r == 'n-sub' ||
        r == 'naib subedar' ||
        r.contains('n/sub')) {
      return 'N/Sub';
    }
    if (r == 'sub' || r == 'subedar') return 'Sub';

    // 3. Soldiers
    if (r.contains('hav') ||
        r.contains('bqmh') ||
        r.contains('rqmh') ||
        r == 'havildar') {
      return 'Hav';
    }
    if (r == 'lhav' ||
        r == 'lhv' ||
        r == 'lance havildar' ||
        r.contains('lhav') ||
        r.contains('lhv')) {
      return 'Lhav';
    }
    if (r == 'lnk' ||
        r == 'l/nk' ||
        r == 'lance naik' ||
        r.contains('lnk') ||
        r.contains('l/nk')) {
      return 'Lnk';
    }
    if (r == 'nk' || r == 'naik' || r == 'nco' || r.contains('nk')) {
      return 'Nk';
    }

    return 'Sep';
  }

  String _getRankCategory(String rank, String name) {
    final sub = _getRankSubcategory(rank, name);
    if (['Lt Col', 'Maj', 'Capt', 'Lt', '2/Lt'].contains(sub)) {
      return 'OFFICERS';
    }
    if (['SM', 'Sub', 'N/Sub'].contains(sub)) {
      return 'JCOs';
    }
    return 'SOLDIERS';
  }

  String _getTrade(Map<String, String> person) {
    final cat = person['category'] ?? '';
    final name = person['name'] ?? '';

    if (cat == 'Officers') return 'Officer';
    if (cat == 'JCOs') {
      if (name.toLowerCase().contains('clk')) return 'Clk';
      if (name.toLowerCase().contains('ta')) return 'TA';
      if (name.toLowerCase().contains('ocu')) return 'OCU';
      if (name.toLowerCase().contains('dmt')) return 'DMT';
      if (name.toLowerCase().contains('dsv')) return 'DSV';
      if (name.toLowerCase().contains('svy')) return 'Svy';
      return 'Gnr';
    }

    if (cat == 'Clks') return 'Clk';
    if (cat == 'Svys') return 'Svy';
    if (cat == 'TAs') return 'TA';
    if (cat == 'OCsU') return 'OCU';
    if (cat == 'DSVs') return 'DSV';
    if (cat == 'DMTs') return 'DMT';
    if (cat == 'Gnrs') return 'Gnr';
    if (cat == 'C/Us') return 'Ck';
    if (cat == 'SWs') return 'S/W';
    if (cat == 'NCBs') return 'NCB';
    if (cat == 'Civs' || cat.toLowerCase().contains('civ')) return 'Civ';
    if (cat == 'LADs' || cat.toLowerCase().contains('lad')) return 'LAD';
    return 'Gnr';
  }

  String _getBattery(Map<String, String> person) {
    if (person['battery'] != null && person['battery']!.isNotEmpty) {
      return person['battery']!;
    }
    final armyNo = person['armyNo'] ?? '';
    final cleanNo = armyNo.replaceAll(RegExp(r'\D'), '');
    if (cleanNo.isEmpty) return 'HQ Bty';
    final id = int.tryParse(cleanNo) ?? 0;

    final btys = ['HQ Bty', 'P Bty', 'Q Bty', 'R Bty'];
    return btys[id % 4];
  }

  /// Returns the color associated with a battery name.
  Color _getBatteryColor(String bty) {
    switch (bty) {
      case 'HQ Bty':
        return const Color(0xFFE53935); // Red - Headquarter Battery
      case 'P Bty':
        return const Color(0xFF9E9E9E); // Light Gray - Papa Battery
      case 'Q Bty':
        return const Color(0xFFFF9800); // Light Orange - Quebec Battery
      case 'R Bty':
        return const Color(0xFF4CAF50); // Light Green - Romeo Battery
      default:
        return const Color(0xFFE53935);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the pre-filtered base list (from analysis tab) if provided, otherwise full list
    final sourceList = widget.baseList ?? nominalRollList;
    final rawList = sourceList.where((p) {
      // Must match the status category (e.g. 'Present', 'Leave')
      if (widget.getPersonStatus(p) != widget.categoryName) return false;
      // If launched from Fighting panel, show only fighting personnel; Non-Fighting panel → non-fighting only
      if (widget.filterIsFighting != null) {
        final fighting = _isFighting(p);
        if (widget.filterIsFighting! && !fighting) return false;
        if (!widget.filterIsFighting! && fighting) return false;
      }
      return true;
    }).toList();

    // Compute which values are actually present in rawList (for disabling irrelevant dropdown items)
    final availableBatteries = rawList.map((p) => _getBattery(p)).toSet();
    final availableTrades = rawList.map((p) => _getTrade(p)).toSet();
    final availableRanks = <String>{};
    for (final p in rawList) {
      final subcat = _getRankSubcategory(p['rank'] ?? '', p['name'] ?? '');
      final cat = _getRankCategory(p['rank'] ?? '', p['name'] ?? '');
      availableRanks.add('  $subcat');
      if (cat == 'OFFICERS') {
        availableRanks.add('Officers');
      } else if (cat == 'JCOs') {
        availableRanks.add('JCOs');
      } else {
        availableRanks.add('Soldiers');
      }
    }

    final filteredList = rawList.where((person) {
      final name = (person['name'] ?? '').toLowerCase();
      final armyNo = (person['armyNo'] ?? '').toLowerCase();
      final matchesSearch =
          name.contains(_searchQuery) || armyNo.contains(_searchQuery);
      if (!matchesSearch) return false;

      if (_selectedDivision != 'All') {
        final selectedDiv = _selectedDivision.trim().toLowerCase();
        final isFighting = _isFighting(person);

        if (selectedDiv == 'fighting') {
          if (!isFighting) return false;
        } else if (selectedDiv == 'non fighting') {
          if (isFighting) return false;
        } else {
          final trade = _getTrade(person);
          if (trade.toLowerCase() != selectedDiv) return false;
          if (isFighting) return false;
        }
      }

      if (_selectedBattery != 'All') {
        final bty = _getBattery(person);
        if (bty != _selectedBattery) return false;
      }

      if (_selectedRankCategory != 'All') {
        final selectedRank = _selectedRankCategory.trim();
        final subcat = _getRankSubcategory(
          person['rank'] ?? '',
          person['name'] ?? '',
        );
        final cat = _getRankCategory(
          person['rank'] ?? '',
          person['name'] ?? '',
        );

        if (selectedRank == 'Officers') {
          if (cat != 'OFFICERS') return false;
        } else if (selectedRank == 'JCOs') {
          if (cat != 'JCOs') return false;
        } else if (selectedRank == 'Soldiers' ||
            selectedRank == 'Sldrs' ||
            selectedRank == 'SLDRS') {
          if (cat != 'SOLDIERS') return false;
        } else {
          if (subcat.toLowerCase() != selectedRank.toLowerCase()) return false;
        }
      }

      if (_selectedTrade != 'All') {
        final trade = _getTrade(person);
        if (trade != _selectedTrade) return false;
      }

      return true;
    }).toList();

    return Theme(
      data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: widget.isDark
            ? const Color(0xFF03140A)
            : const Color(0xFFE8F5EE),
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
            widget.filterIsFighting == null
                ? '${widget.categoryName} · ${rawList.length} Pers'
                : widget.filterIsFighting!
                ? 'Fighting · ${widget.categoryName} · ${rawList.length} Pers'
                : 'Non-Fighting · ${widget.categoryName} · ${rawList.length} Pers',
            style: TextStyle(
              color: widget.textThemeColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF0C5A32).withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark
                        ? widget.goldAccent.withValues(alpha: 0.25)
                        : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: widget.textThemeColor,
                        fontSize: 13.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search Name or Army No...',
                        hintStyle: TextStyle(
                          color: widget.textThemeColor.withValues(alpha: 0.5),
                          fontSize: 13.5,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: widget.goldAccent,
                          size: 18,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: widget.silverText,
                                  size: 18,
                                ),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: widget.isDark
                            ? const Color(0xFF03140A)
                            : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: widget.goldAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: widget.goldAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterDropdown(
                            label: 'Div',
                            value: _selectedDivision,
                            items: const [
                              'All',
                              'Fighting',
                              'Non Fighting',
                              '  Clk',
                              '  Ck',
                              '  Civ',
                              '  LAD',
                              '  NCB',
                              '  S/W',
                              '  Engr',
                              '  N/A',
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedDivision = val ?? 'All';
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterDropdown(
                            label: 'Battery',
                            value: _selectedBattery,
                            items: _batteriesList,
                            availableValues: availableBatteries,
                            onChanged: (val) {
                              setState(() {
                                _selectedBattery = val ?? 'All';
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterDropdown(
                            label: 'Rank',
                            value: _selectedRankCategory,
                            items: _ranksList,
                            availableValues: availableRanks,
                            onChanged: (val) {
                              setState(() {
                                _selectedRankCategory = val ?? 'All';
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterDropdown(
                            label: 'Trade',
                            value: _selectedTrade,
                            items: _tradesList,
                            availableValues: availableTrades,
                            onChanged: (val) {
                              setState(() {
                                _selectedTrade = val ?? 'All';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Text(
                        'No Personnel Found',
                        style: TextStyle(
                          color: widget.silverText,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final person = filteredList[index];
                        final isFighting = _isFighting(person);
                        final bty = _getBattery(person);
                        final btyColor = _getBatteryColor(bty);
                        final armyNo = person['armyNo'] ?? '';
                        final rank = person['rank'] ?? '';
                        final name = person['name'] ?? '';
                        final cl = person['cl'] ?? '';
                        final remarks = person['remarks'] ?? '';
                        final category = person['category'] ?? '';

                        final status = widget.getPersonStatus(person);
                        final statusColor =
                            (status == 'Present' ||
                                status == 'Working' ||
                                status == 'Aval')
                            ? widget.valueGreenColor
                            : (status == 'Leave' ||
                                  status == 'OSL/Pris' ||
                                  status.toLowerCase().contains('sick') ||
                                  status.toLowerCase().contains('cmh'))
                            ? Colors.redAccent
                            : widget.goldAccent;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PersonnelIdCardScreen(
                                  person: person,
                                  isDark: widget.isDark,
                                  textThemeColor: widget.textThemeColor,
                                  silverText: widget.silverText,
                                  goldAccent: widget.goldAccent,
                                  valueGreenColor: widget.valueGreenColor,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? const Color(
                                      0xFF0C5A32,
                                    ).withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: btyColor.withValues(alpha: 0.45),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.isDark
                                      ? Colors.black.withValues(alpha: 0.12)
                                      : const Color(
                                          0xFF0C5A32,
                                        ).withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Battery color indicator strip
                                    Container(
                                      width: 5,
                                      decoration: BoxDecoration(
                                        color: btyColor,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(15),
                                          bottomLeft: Radius.circular(15),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                // Avatar circle with rank initials and status dot indicator
                                                Stack(
                                                  children: [
                                                    Container(
                                                      width: 44,
                                                      height: 44,
                                                      decoration: BoxDecoration(
                                                        color: widget.goldAccent
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: widget
                                                              .goldAccent
                                                              .withValues(
                                                                alpha: 0.35,
                                                              ),
                                                          width: 1.2,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          rank,
                                                          style: TextStyle(
                                                            color: widget
                                                                .goldAccent,
                                                            fontSize: 10.5,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 1,
                                                      bottom: 1,
                                                      child: Container(
                                                        width: 11,
                                                        height: 11,
                                                        decoration: BoxDecoration(
                                                          color: statusColor,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: widget.isDark
                                                                ? const Color(
                                                                    0xFF03140A,
                                                                  )
                                                                : Colors.white,
                                                            width: 2.0,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 12),
                                                // Middle details (Name, Army No, Bty)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: TextStyle(
                                                          color: widget
                                                              .textThemeColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 4,
                                                        crossAxisAlignment:
                                                            WrapCrossAlignment
                                                                .center,
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 1.5,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  widget.isDark
                                                                  ? const Color(
                                                                      0xFF03140A,
                                                                    )
                                                                  : const Color(
                                                                      0xFFE8F5EE,
                                                                    ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              armyNo,
                                                              style: TextStyle(
                                                                color: widget
                                                                    .valueGreenColor,
                                                                fontSize: 10.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                          // Battery color chip
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 7,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: btyColor
                                                                  .withValues(
                                                                    alpha: 0.13,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    5,
                                                                  ),
                                                              border: Border.all(
                                                                color: btyColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    ),
                                                                width: 0.8,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              bty,
                                                              style: TextStyle(
                                                                color: btyColor,
                                                                fontSize: 10.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            'Cl: $cl',
                                                            style: TextStyle(
                                                              color: widget
                                                                  .silverText,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Right Side metadata (Status badge and category indicator)
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: statusColor
                                                            .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color: statusColor
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: widget.isDark
                                                            ? const Color(
                                                                0xFF0C5A32,
                                                              ).withValues(
                                                                alpha: 0.05,
                                                              )
                                                            : const Color(
                                                                0xFF0C5A32,
                                                              ).withValues(
                                                                alpha: 0.03,
                                                              ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: isFighting
                                                              ? widget
                                                                    .valueGreenColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    )
                                                              : Colors.orange
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                          width: 0.6,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        category,
                                                        style: TextStyle(
                                                          color: isFighting
                                                              ? widget
                                                                    .valueGreenColor
                                                              : Colors.orange,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (remarks.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: widget.isDark
                                                      ? const Color(
                                                          0xFF03140A,
                                                        ).withValues(alpha: 0.4)
                                                      : const Color(
                                                          0xFF0C5A32,
                                                        ).withValues(
                                                          alpha: 0.02,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: widget.goldAccent
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .assignment_ind_rounded,
                                                      color: widget.goldAccent,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        remarks,
                                                        style: TextStyle(
                                                          color: widget.isDark
                                                              ? const Color(
                                                                  0xFFD0D0D0,
                                                                )
                                                              : const Color(
                                                                  0xFF3B4D41,
                                                                ),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Set<String>? availableValues, // items NOT in this set are shown disabled
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 38,
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF03140A)
            : const Color(0xFFE8F5EE).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.goldAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: widget.isDark ? const Color(0xFF0A2214) : Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: widget.goldAccent, size: 18),
          style: TextStyle(
            color: widget.textThemeColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          items: items.map<DropdownMenuItem<String>>((String val) {
            final isAvailable =
                availableValues == null ||
                val == 'All' ||
                availableValues.contains(val);
            return DropdownMenuItem<String>(
              value: val,
              enabled: isAvailable,
              child: Text(
                val == 'All' ? '$label: All' : val,
                style: TextStyle(
                  color: isAvailable
                      ? (val == value
                            ? widget.goldAccent
                            : widget.textThemeColor)
                      : (widget.isDark ? Colors.white24 : Colors.black26),
                  fontWeight: val == value
                      ? FontWeight.w800
                      : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class PersonnelIdCardScreen extends StatelessWidget {
  final Map<String, String> person;
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;

  const PersonnelIdCardScreen({
    super.key,
    required this.person,
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
  });

  bool _isFighting(Map<String, String> person) {
    if (person['isFighting'] == 'false') return false;
    if (person['isFighting'] == 'true') return true;
    final cat = person['category'] ?? '';
    if (cat == 'Officers' ||
        cat == 'JCOs' ||
        cat == 'Svys' ||
        cat == 'TAs' ||
        cat == 'OCsU' ||
        cat == 'DSVs' ||
        cat == 'DMTs' ||
        cat == 'Gnrs') {
      return true;
    }
    return false;
  }

  String _getTrade(Map<String, String> person) {
    final cat = person['category'] ?? '';
    final name = person['name'] ?? '';

    if (cat == 'Officers') return 'Officer';
    if (cat == 'JCOs') {
      if (name.toLowerCase().contains('clk')) return 'Clk';
      if (name.toLowerCase().contains('ta')) return 'TA';
      if (name.toLowerCase().contains('ocu')) return 'OCU';
      if (name.toLowerCase().contains('dmt')) return 'DMT';
      if (name.toLowerCase().contains('dsv')) return 'DSV';
      if (name.toLowerCase().contains('svy')) return 'Svy';
      return 'Gnr';
    }

    if (cat == 'Clks') return 'Clk';
    if (cat == 'Svys') return 'Svy';
    if (cat == 'TAs') return 'TA';
    if (cat == 'OCsU') return 'OCU';
    if (cat == 'DSVs') return 'DSV';
    if (cat == 'DMTs') return 'DMT';
    if (cat == 'Gnrs') return 'Gnr';
    if (cat == 'C/Us') return 'Ck';
    if (cat == 'SWs') return 'SW';
    if (cat == 'NCBs') return 'NCB';
    return 'Gnr';
  }

  String _getBattery(Map<String, String> person) {
    if (person['battery'] != null && person['battery']!.isNotEmpty) {
      return person['battery']!;
    }
    final armyNo = person['armyNo'] ?? '';
    if (armyNo == 'NYA' || armyNo.isEmpty) {
      return 'HQ Bty';
    }
    final cleanNo = armyNo.replaceAll(RegExp(r'\D'), '');
    if (cleanNo.isEmpty) return 'HQ Bty';
    final lastDigit = int.tryParse(cleanNo[cleanNo.length - 1]) ?? 0;
    if (lastDigit == 0 || lastDigit == 4) return 'HQ Bty';
    if (lastDigit == 1 || lastDigit == 5) return 'P Bty';
    if (lastDigit == 2 || lastDigit == 6 || lastDigit == 8) return 'Q Bty';
    return 'R Bty';
  }

  String _getPhoneNumber(Map<String, String> person) {
    if (person['phone'] != null && person['phone']!.isNotEmpty) {
      return person['phone']!;
    }
    final armyNo = person['armyNo'] ?? '';
    final digits = armyNo.replaceAll(RegExp(r'\D'), '');
    final padded = digits.padRight(7, '0');
    return '+92 300 ${padded.substring(0, 3)} ${padded.substring(3, 7)}';
  }

  String _getCity(Map<String, String> person) {
    final armyNo = person['armyNo'] ?? '';
    final cleanNo = armyNo.replaceAll(RegExp(r'\D'), '');
    final id = int.tryParse(cleanNo) ?? 0;
    final cities = [
      'Rawalpindi',
      'Lahore',
      'Karachi',
      'Peshawar',
      'Quetta',
      'Multan',
      'Faisalabad',
      'Islamabad',
      'Gujranwala',
      'Sialkot',
    ];
    return cities[id % cities.length];
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final shortYear = (date.year % 100).toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} $shortYear';
  }

  String _formatDateRange(DateTime date, {bool includeYear = true}) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final shortYear = (date.year % 100).toString().padLeft(2, '0');
    final base =
        '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
    return includeYear ? '$base $shortYear' : base;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, String>? localPersonData;

    return StatefulBuilder(
      builder: (context, setScreenState) {
        localPersonData ??= Map<String, String>.from(person);

        final isFighting = _isFighting(localPersonData!);
        final trade = _getTrade(localPersonData!);
        final phone = _getPhoneNumber(localPersonData!);
        final city = _getCity(localPersonData!);
        final battery = _getBattery(localPersonData!);
        final remarks = localPersonData!['remarks'] ?? '';
        final name = localPersonData!['name'] ?? '';
        final rank = localPersonData!['rank'] ?? '';
        final armyNo = localPersonData!['armyNo'] ?? '';
        final classGroup = localPersonData!['cl'] ?? 'N/A';
        return Theme(
          data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF03140A)
            : const Color(0xFFE8F5EE),
        appBar: AppBar(
          backgroundColor: isDark
              ? const Color(0xFF03140A).withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.85),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: goldAccent),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'MILITARY IDENTIFICATION CARD',
            style: TextStyle(
              color: textThemeColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // THE PHYSICAL CARD CONTAINER
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF051C0F), const Color(0xFF0C3D21)]
                        : [Colors.white, const Color(0xFFE8F5EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: goldAccent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      // Watermark text in background
                      Positioned(
                        right: -20,
                        bottom: -10,
                        child: Opacity(
                          opacity: 0.05,
                          child: Icon(
                            Icons.security_rounded,
                            size: 180,
                            color: goldAccent,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Header: Regiment Title and Flag emblem
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ZARB-UL-HADEED',
                                      style: TextStyle(
                                        color: goldAccent,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const Text(
                                      '117 SP REGIMENT (ARTILLERY)',
                                      style: TextStyle(
                                        color: Color(0xFF8B9B90),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: goldAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: goldAccent.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'OFFICIAL ID',
                                    style: TextStyle(
                                      color: Color(0xFFCD9B2D),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Divider(
                              height: 16,
                              thickness: 1.0,
                              color: Color(0xFFCD9B2D),
                            ),

                            // Middle Info section: Avatar & Quick Info
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Slot: Circular Profile Image with Edit
                                Stack(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: goldAccent.withValues(alpha: 0.8),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: _buildAvatarImage(localPersonData!),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () async {
                                          final picker = ImagePicker();
                                          final XFile? image = await picker.pickImage(
                                            source: ImageSource.gallery,
                                            imageQuality: 50,
                                            maxWidth: 200,
                                            maxHeight: 200,
                                          );
                                          if (image != null) {
                                            final bytes = await image.readAsBytes();
                                            final String base64String = base64Encode(bytes);
                                            final String mimeType = image.mimeType ?? 'image/jpeg';
                                            final base64 = 'data:$mimeType;base64,$base64String';
                                            _updatePersonAvatar(localPersonData!, base64, localPersonData!, setScreenState);
                                          }
                                        },
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: goldAccent,
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),

                                // Right Slot: Primary Metadata fields
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.toUpperCase(),
                                        style: TextStyle(
                                          color: textThemeColor,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Army Number banner
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: valueGreenColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: valueGreenColor.withValues(
                                              alpha: 0.3,
                                            ),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          armyNo,
                                          style: TextStyle(
                                            color: valueGreenColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Rank and Trade side-by-side
                                      Row(
                                        children: [
                                          _buildCardShortField(
                                            'RANK',
                                            rank,
                                            goldAccent,
                                          ),
                                          const SizedBox(width: 16),
                                          _buildCardShortField(
                                            'TRADE',
                                            trade,
                                            goldAccent,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Chip Graphic & Barcode simulation
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Digital Gold Smart Chip representation
                                Container(
                                  width: 32,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE9C54F),
                                        Color(0xFFCD9B2D),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.black26,
                                      width: 0.5,
                                    ),
                                  ),
                                ),

                                // Barcode graphic lines
                                Row(
                                  children: List.generate(12, (index) {
                                    final widths = [
                                      2.0,
                                      4.0,
                                      1.0,
                                      5.0,
                                      2.0,
                                      3.0,
                                      1.0,
                                      4.0,
                                      2.0,
                                      6.0,
                                      1.0,
                                      3.0,
                                    ];
                                    return Container(
                                      width: widths[index],
                                      height: 24,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black45,
                                      margin: const EdgeInsets.only(right: 2),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // DETAILS LIST PANEL (Data Entry Information Fields)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0C5A32).withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? goldAccent.withValues(alpha: 0.25)
                        : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.1)
                          : const Color(0xFF0C5A32).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DATA ENTRY INFORMATION FIELDS',
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Divider(height: 20, thickness: 0.5),

                    _buildInfoDetailRow(
                      icon: Icons.shield_outlined,
                      label: 'Combat Classification',
                      value: isFighting ? 'Fighting' : 'Non Fighting',
                      valueColor: isFighting ? valueGreenColor : Colors.orange,
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.location_on_rounded,
                      label: 'Current Assignment / Location',
                      value: PersonnelDataManager()
                          .getStatus(armyNo)
                          .displayPath,
                      valueColor: goldAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditAssignmentScreen(
                              person: person,
                              isDark: isDark,
                              textThemeColor: textThemeColor,
                              silverText: silverText,
                              goldAccent: goldAccent,
                              valueGreenColor: valueGreenColor,
                              onSaved: () {
                                setScreenState(() {});
                              },
                            ),
                          ),
                        ).then((_) {
                          setScreenState(() {});
                        });
                      },
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Assignment Period',
                      value: () {
                        final status = PersonnelDataManager().getStatus(armyNo);
                        final startStr = _formatDate(status.startDate);
                        final endStr = status.endDate != null
                            ? _formatDate(status.endDate!)
                            : 'Infinite';
                        return '$startStr to $endStr';
                      }(),
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Army Number',
                      value: armyNo,
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.person_rounded,
                      label: 'Full Name',
                      value: name,
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.work_outline_rounded,
                      label: 'Trade / Role',
                      value: trade,
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.military_tech_rounded,
                      label: 'Rank',
                      value: rank,
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.badge_rounded,
                      label: 'Class Group',
                      value: classGroup,
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.shield_rounded,
                      label: 'Sub Unit / Battery',
                      value: battery,
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone Number',
                      value: phone,
                      onTap: () {
                        _showPhoneOptionsSheet(
                          context,
                          phone,
                          isDark,
                          textThemeColor,
                          silverText,
                          goldAccent,
                        );
                      },
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.location_city_rounded,
                      label: 'Home City',
                      value: city,
                    ),
                    _buildInfoDetailRow(
                      icon: Icons.assignment_rounded,
                      label: 'Remarks / Observations',
                      value: remarks.isNotEmpty
                          ? remarks
                          : 'No active remarks or observations recorded.',
                      isItalic: remarks.isEmpty,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SEE HISTORY BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showHistoryDialog(context, name, armyNo);
                  },
                  icon: Icon(
                    Icons.history_rounded,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  label: Text(
                    'SEE MOVEMENT HISTORY',
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildCardShortField(String label, String value, Color goldAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B9B90),
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: goldAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isItalic = false,
    VoidCallback? onTap,
  }) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: goldAccent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF8B9B90),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? textThemeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }

  Color _getHistoryDotColor(PersonStatus record) {
    final locationText = record.displayPath.toLowerCase();
    final isPresent =
        locationText.contains('present') ||
        locationText.contains('sta gds') ||
        locationText.contains('unit gds') ||
        locationText.contains('regt emp') ||
        locationText.contains('trg') ||
        locationText.contains('sports') ||
        locationText.contains('aslt course') ||
        locationText.contains('working') ||
        locationText.contains('prot');
    return isPresent ? valueGreenColor : Colors.orange;
  }

  void _showHistoryDialog(BuildContext context, String name, String armyNo) {
    int selectedDays = 90;

    final person = nominalRollList.firstWhere(
      (p) => p['armyNo'] == armyNo,
      orElse: () => {'rank': 'Gnr', 'name': name, 'armyNo': armyNo, 'category': 'Gnrs'},
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setScreenState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final goldAccent = isDark ? const Color(0xFFD4AF37) : const Color(0xFF1B4D3E);
              final silverText = isDark ? const Color(0xFFA8B2A1) : Colors.grey[700]!;

              final DateTime filterDate = DateTime.now().subtract(
                Duration(days: selectedDays),
              );
              
              return FutureBuilder<List<PersonStatus>>(
                future: PersonnelDataManager().getHistory(armyNo),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(
                      backgroundColor: isDark ? const Color(0xFF051C0F) : Colors.white,
                      appBar: AppBar(
                        backgroundColor: goldAccent.withValues(alpha: isDark ? 0.14 : 0.10),
                        elevation: 0,
                        leading: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: goldAccent, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: Text(
                          'MOVEMENT HISTORY',
                          style: TextStyle(
                            color: goldAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      body: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  final allHistory = snapshot.data ?? [];
                  final filteredHistory = selectedDays == 0
                      ? List<PersonStatus>.from(allHistory)
                      : allHistory.where(
                          (status) =>
                              status.startDate.isAfter(filterDate) ||
                              (status.endDate == null || status.endDate!.isAfter(filterDate)),
                        ).toList();
                  
                  filteredHistory.sort((a, b) => b.startDate.compareTo(a.startDate));

                  final List<MovementRecord> records = filteredHistory.map((status) {
                    final String duration;
                    if (status.endDate != null) {
                      final days = status.endDate!.difference(status.startDate).inDays;
                      duration = '$days Days';
                    } else {
                      duration = '-';
                    }

                    final String dateRange;
                    if (status.endDate != null) {
                      dateRange = '${_formatDate(status.startDate)} to ${_formatDate(status.endDate!)}';
                    } else {
                      dateRange = '${_formatDate(status.startDate)} to Present';
                    }

                    return MovementRecord(
                      dateRange: dateRange,
                      movement: status.displayPath.replaceAll(' -> ', ' → '),
                      duration: duration,
                      dotColor: status.endDate == null ? const Color(0xFFF39C12) : const Color(0xFF1B4D3E),
                    );
                  }).toList();

              return Scaffold(
                backgroundColor: isDark ? const Color(0xFF051C0F) : Colors.white,
                appBar: AppBar(
                  backgroundColor: goldAccent.withValues(alpha: isDark ? 0.14 : 0.10),
                  elevation: 0,
                  centerTitle: false,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: goldAccent, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOVEMENT HISTORY',
                        style: TextStyle(
                          color: goldAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '${person['rank'] ?? 'Gnr'} $name ($armyNo) • Trade: ${_getTrade(person)}',
                        style: TextStyle(
                          color: silverText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  actions: const [],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1.0),
                    child: Container(
                      color: goldAccent.withValues(alpha: 0.2),
                      height: 1.0,
                    ),
                  ),
                ),
                body: records.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No history records found for this period.',
                            style: TextStyle(color: silverText, fontSize: 14),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        physics: const BouncingScrollPhysics(),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 850),
                            child: MovementHistoryWidget(
                              records: records,
                              selectedDays: selectedDays,
                              onDaysChanged: (value) {
                                setScreenState(() {
                                    selectedDays = value;
                                  });
                              },
                            ),
                          ),
                        ),
                      ),
              );
                }
              );
            },
          );
        },
      ),
    );
  }

  void _showPhoneOptionsSheet(
    BuildContext context,
    String phone,
    bool isDark,
    Color textThemeColor,
    Color silverText,
    Color goldAccent,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF051C0F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: silverText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                phone,
                style: TextStyle(
                  color: textThemeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.call_rounded, color: goldAccent),
                title: Text(
                  'Call / Open Dial Pad',
                  style: TextStyle(
                    color: textThemeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
                  final Uri telLaunchUri = Uri(
                    scheme: 'tel',
                    path: cleanPhone,
                  );
                  if (await canLaunchUrl(telLaunchUri)) {
                    await launchUrl(telLaunchUri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not launch dial pad'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: goldAccent),
                title: Text(
                  'Copy Phone Number',
                  style: TextStyle(
                    color: textThemeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0C5A32),
                      content: Text(
                        'Copied $phone to clipboard',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarImage(Map<String, String> person) {
    final avatar = person['avatar'] ?? '';
    if (avatar.isEmpty) {
      return Image.asset(
        'assets/images/profile_avatar.jpg',
        key: const ValueKey('default_person'),
        fit: BoxFit.cover,
      );
    }
    if (avatar.startsWith('data:image')) {
      try {
        final cleanBase64 = avatar.split(',').last;
        final bytes = base64Decode(cleanBase64);
        return Image.memory(
          bytes,
          key: ValueKey(avatar),
          fit: BoxFit.cover,
        );
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return Image.asset(
          'assets/images/profile_avatar.jpg',
          key: const ValueKey('error_person'),
          fit: BoxFit.cover,
        );
      }
    }
    if (avatar.startsWith('http')) {
      return Image.network(
        avatar,
        key: ValueKey(avatar),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/profile_avatar.jpg',
            key: const ValueKey('net_error_person'),
            fit: BoxFit.cover,
          );
        },
      );
    }
    if (avatar.startsWith('assets/')) {
      return Image.asset(
        avatar,
        key: ValueKey(avatar),
        fit: BoxFit.cover,
      );
    }
    return Image.asset(
      'assets/images/profile_avatar.jpg',
      key: ValueKey(avatar),
      fit: BoxFit.cover,
    );
  }

  Future<void> _updatePersonAvatar(
    Map<String, String> person,
    String avatarUrl,
    Map<String, String> localPersonData,
    void Function(void Function()) setScreenState,
  ) async {
    final armyNo = person['armyNo'] ?? '';
    if (armyNo.isEmpty) return;

    final manager = PersonnelDataManager();
    final updatedPerson = Map<String, String>.from(person);
    updatedPerson['avatar'] = avatarUrl;

    await manager.editPerson(armyNo, updatedPerson);

    setScreenState(() {
      localPersonData['avatar'] = avatarUrl;
    });
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String> initialSelectedValues;
  final bool isDark;
  final Color goldAccent;
  final Color textThemeColor;
  final ValueChanged<List<String>> onApply;

  const _MultiSelectDialog({
    required this.title,
    required this.items,
    required this.initialSelectedValues,
    required this.isDark,
    required this.goldAccent,
    required this.textThemeColor,
    required this.onApply,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late List<String> _tempSelectedValues;

  @override
  void initState() {
    super.initState();
    _tempSelectedValues = List.from(widget.initialSelectedValues);
    if (_tempSelectedValues.isEmpty) {
      _tempSelectedValues.add('All');
    }
  }

  void _toggleItem(String item) {
    setState(() {
      if (item == 'All') {
        _tempSelectedValues = ['All'];
      } else {
        _tempSelectedValues.remove('All');
        if (_tempSelectedValues.contains(item)) {
          _tempSelectedValues.remove(item);
          if (_tempSelectedValues.isEmpty) {
            _tempSelectedValues.add('All');
          }
        } else {
          _tempSelectedValues.add(item);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.isDark ? const Color(0xFF03140A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isDark
              ? widget.goldAccent.withValues(alpha: 0.3)
              : const Color(0xFF0C5A32).withValues(alpha: 0.15),
        ),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: widget.goldAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isHeader = item == 'Officers' || item == 'JCOs' || item == 'Soldiers';
                  final isSelected = _tempSelectedValues.contains(item);
                  return CheckboxListTile(
                    activeColor: widget.goldAccent,
                    checkColor: widget.isDark ? Colors.black : Colors.white,
                    title: Text(
                      item,
                      style: TextStyle(
                        color: widget.textThemeColor,
                        fontSize: isHeader ? 13 : 12,
                        fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    value: isSelected,
                    onChanged: (bool? checked) {
                      _toggleItem(item);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: widget.isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.goldAccent,
                    foregroundColor: widget.isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    widget.onApply(_tempSelectedValues);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

