import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/battery_detail_viewmodel.dart';

/// Battery Detail Screen — shows all personnel of a specific battery
/// with rank-wise breakdown, strength summary, and searchable list.
class BatteryDetailScreen extends StatelessWidget {
  final String batteryKey;   // e.g. 'HQ Bty'
  final String batteryName;  // e.g. 'HQ Battery'
  final Color batteryColor;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const BatteryDetailScreen({
    super.key,
    required this.batteryKey,
    required this.batteryName,
    required this.batteryColor,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BatteryDetailViewModel(batteryKey: batteryKey),
      child: _BatteryDetailScreenContent(
        batteryKey: batteryKey,
        batteryName: batteryName,
        batteryColor: batteryColor,
        isDarkMode: isDarkMode,
        onToggleTheme: onToggleTheme,
      ),
    );
  }
}

class _BatteryDetailScreenContent extends StatefulWidget {
  final String batteryKey;
  final String batteryName;
  final Color batteryColor;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const _BatteryDetailScreenContent({
    required this.batteryKey,
    required this.batteryName,
    required this.batteryColor,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<_BatteryDetailScreenContent> createState() => _BatteryDetailScreenContentState();
}

class _BatteryDetailScreenContentState extends State<_BatteryDetailScreenContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerAnimCtrl;
  final TextEditingController _searchCtrl = TextEditingController();

  Color _statusColor(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'present': return const Color(0xFF00C853);
      case 'leave':   return const Color(0xFFFF9800);
      case 'att':     return const Color(0xFF2196F3);
      case 'cmh/sick':return const Color(0xFFE53935);
      default:        return isDark ? const Color(0xFFB0B0B0) : const Color(0xFF6D6D6D);
    }
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _headerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _searchCtrl.addListener(() {
      context.read<BatteryDetailViewModel>().setSearchQuery(_searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _headerAnimCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BatteryDetailViewModel>();
    final isDark = widget.isDarkMode;
    final accent = widget.batteryColor;
    final bgColor = isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE);
    final cardBg  = isDark ? const Color(0xFF07200F) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF042011);
    final subText   = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF4A5D52);
    final goldAccent = isDark ? const Color(0xFFCD9B2D) : const Color(0xFF9E7715);

    final stats = viewModel.stats;
    final personnel = viewModel.filteredPersonnel;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      // ── App Bar ──────────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: isDark
              ? const Color(0xFF03140A).withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.92),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: accent.withValues(alpha: 0.3),
                      width: 1.2,
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
                    colors: [accent, accent.withValues(alpha: 0.7), accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    widget.batteryName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Text(
                  '117 SP REGT  ·  ${stats['total']} Personnel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subText,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : const Color(0xFF042011), size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 8.0),
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: isDark ? Colors.white : const Color(0xFF0C5A32),
                  size: 22,
                ),
                onPressed: widget.onToggleTheme,
              ),
            ),
          ],
        ),
      ),

      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 80),
          ),

          // ── Strength Summary Cards ────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _headerAnimCtrl, curve: Curves.easeOut),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // Total strength banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: isDark ? 0.22 : 0.12),
                            accent.withValues(alpha: isDark ? 0.06 : 0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Battery icon / emblem
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                widget.batteryName.substring(0, 2).toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL STRENGTH',
                                  style: TextStyle(
                                    color: subText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  '${stats['total']}',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Fighting ratio pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accent.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${stats['total']! > 0 ? (((stats['officers']! + stats['jcos']! + stats['sldrs']!) / stats['total']!) * 100).toStringAsFixed(0) : 0}%',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'Fighting',
                                  style: TextStyle(color: subText, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 4 mini stat cards
                    Row(
                      children: [
                        _miniStatCard('Officers', stats['officers']!, const Color(0xFF5C6BC0), isDark, cardBg),
                        const SizedBox(width: 8),
                        _miniStatCard('JCOs', stats['jcos']!, const Color(0xFF26A69A), isDark, cardBg),
                        const SizedBox(width: 8),
                        _miniStatCard('Sldrs', stats['sldrs']!, accent, isDark, cardBg),
                        const SizedBox(width: 8),
                        _miniStatCard('Non-Fgt', stats['nonFighting']!, const Color(0xFF8D6E63), isDark, cardBg),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Composition breakdown bar
                    _fightingRatioBar(stats, accent, textColor, subText, isDark),
                  ],
                ),
              ),
            ),
          ),

          // ── Search + Filter Row ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  // Search bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by name, rank, or army no…',
                        hintStyle: TextStyle(color: subText, fontSize: 12),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search_rounded, color: accent, size: 20),
                        suffixIcon: viewModel.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: subText, size: 16),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Category filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'All',
                        'Officers',
                        'Lt Col',
                        'Maj',
                        'Capt',
                        'Lt',
                        '2/Lt',
                        'JCOs',
                        'SM',
                        'Sub',
                        'N/Sub',
                        'Sldrs',
                        'Hav',
                        'Lhav',
                        'Nk',
                        'Lnk',
                        'Sep',
                        'Non-Fighting',
                        'Clk',
                        'Ck',
                        'Civ',
                        'LAD',
                        'NCB',
                        'S/W',
                      ]
                          .map((cat) => _filterChip(viewModel, cat, accent, textColor, subText, isDark))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Section Header ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    color: accent,
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  Text(
                    'PERSONNEL LIST',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${personnel.length} shown',
                    style: TextStyle(color: subText, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          // ── Personnel List ───────────────────────────────────────────────
          if (personnel.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search_outlined, size: 48, color: subText),
                    const SizedBox(height: 12),
                    Text('No personnel found', style: TextStyle(color: subText, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final p = personnel[i];
                  return _buildPersonCard(viewModel, p, i, accent, textColor, subText, goldAccent, cardBg, isDark);
                },
                childCount: personnel.length,
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ─── Sub-widgets ─────────────────────────────────────────────────────────

  Widget _miniStatCard(String label, int value, Color color, bool isDark, Color cardBg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? color.withValues(alpha: 0.1) : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fightingRatioBar(
    Map<String, int> stats,
    Color accent,
    Color textColor,
    Color subText,
    bool isDark,
  ) {
    final total = stats['total']! > 0 ? stats['total']! : 1;
    final officers = stats['officers']!;
    final jcos = stats['jcos']!;
    final sldrs = stats['sldrs']!;
    final nonFgt = stats['nonFighting']!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFF0C5A32).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPOSITION BREAKDOWN',
            style: TextStyle(
              color: isDark ? const Color(0xFFCD9B2D) : const Color(0xFF9E7715),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (officers > 0)
                    _barSegment(officers / total, const Color(0xFF5C6BC0)),
                  if (jcos > 0)
                    _barSegment(jcos / total, const Color(0xFF26A69A)),
                  if (sldrs > 0)
                    _barSegment(sldrs / total, accent),
                  if (nonFgt > 0)
                    _barSegment(nonFgt / total, const Color(0xFF8D6E63)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legend('Officers', officers, const Color(0xFF5C6BC0), subText),
              _legend('JCOs', jcos, const Color(0xFF26A69A), subText),
              _legend('Sldrs', sldrs, accent, subText),
              _legend('Non-Fgt', nonFgt, const Color(0xFF8D6E63), subText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barSegment(double fraction, Color color) => Flexible(
        flex: (fraction * 1000).round(),
        child: Container(color: color),
      );

  Widget _legend(String label, int value, Color color, Color subText) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(color: subText, fontSize: 10),
          ),
        ],
      );

  Widget _filterChip(
    BatteryDetailViewModel viewModel,
    String label,
    Color accent,
    Color textColor,
    Color subText,
    bool isDark,
  ) {
    final isSelected = viewModel.filterCategory == label;
    return GestureDetector(
      onTap: () => viewModel.setFilterCategory(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? accent
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : accent.withValues(alpha: 0.3),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : subText,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonCard(
    BatteryDetailViewModel viewModel,
    Map<String, String> p,
    int index,
    Color accent,
    Color textColor,
    Color subText,
    Color goldAccent,
    Color cardBg,
    bool isDark,
  ) {
    final name = p['name'] ?? '—';
    final rank = p['rank'] ?? '—';
    final armyNo = p['armyNo'] ?? '—';
    final cl = p['cl'] ?? '—';
    final remarks = p['remarks'] ?? '';
    final isFighting = viewModel.isFighting(p);
    final status = viewModel.getStatus(p);
    final statusColor = _statusColor(status, isDark);
    final rankCat = viewModel.getRankCategory(rank, name);

    // Category chip styling
    Color catColor;
    String catLabel;
    if (!isFighting) {
      catColor = const Color(0xFF8D6E63);
      catLabel = 'Non-Fgt';
    } else if (rankCat == 'OFFICERS') {
      catColor = const Color(0xFF5C6BC0);
      catLabel = 'Offr';
    } else if (rankCat == 'JCOs') {
      catColor = const Color(0xFF26A69A);
      catLabel = 'JCO';
    } else {
      catColor = accent;
      catLabel = 'Sldr';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? cardBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: catColor.withValues(alpha: 0.25),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: name + status + category chip
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Category chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: catColor.withValues(alpha: 0.35), width: 0.8),
                            ),
                            child: Text(
                              catLabel,
                              style: TextStyle(
                                color: catColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Bottom: rank | army no | CL | remarks
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _detailPill(Icons.military_tech_outlined, rank, goldAccent, subText),
                          _detailPill(Icons.badge_outlined, armyNo, subText, subText),
                          _detailPill(Icons.location_on_outlined, 'CL: $cl', subText, subText),
                          if (remarks.isNotEmpty)
                            _detailPill(Icons.info_outline_rounded, remarks,
                                subText.withValues(alpha: 0.7), subText),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailPill(IconData icon, String text, Color iconColor, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: iconColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
