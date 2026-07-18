import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../services/personnel_data.dart';

class GroupDetailScreen extends StatelessWidget {
  final GroupModel group;
  final bool isDark;
  final Color textThemeColor;
  final Color silverText;
  final Color goldAccent;
  final Color valueGreenColor;

  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.isDark,
    required this.textThemeColor,
    required this.silverText,
    required this.goldAccent,
    required this.valueGreenColor,
  });

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'travel':
        return Colors.blue.shade300;
      case 'training':
        return Colors.green.shade300;
      case 'sports':
        return Colors.purple.shade300;
      case 'working party':
        return Colors.red.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  List<Map<String, String>> _getAssignedPersonnelDetails() {
    return group.assignedPersonnel
        .map((armyNo) {
          final person = nominalRollList.firstWhere(
            (p) => p['armyNo'] == armyNo,
            orElse: () => {
              'armyNo': armyNo,
              'rank': '?',
              'name': 'Unknown',
              'category': '',
              'cl': '',
              'remarks': '',
            },
          );
          return person;
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor(group.category);
    final assignedDetails = _getAssignedPersonnelDetails();
    final dateStr = _formatDate(group.untilDate);

    // Group persons by category
    final Map<String, List<Map<String, String>>> grouped = {};
    for (final person in assignedDetails) {
      final cat = person['category'] ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(person);
    }

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE),
        body: Column(
          children: [
            // ─── Header ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 24,
                left: 8,
                right: 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF064420),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button row
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: goldAccent),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Group Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Group name + category badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: catColor.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            group.category,
                            style: TextStyle(
                              color: catColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info chips row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.person_outline_rounded,
                          label: group.leaderName,
                          color: goldAccent,
                        ),
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: group.location,
                          color: goldAccent,
                        ),
                        _InfoChip(
                          icon: Icons.calendar_today_outlined,
                          label: 'Until $dateStr',
                          color: Colors.white60,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Stats bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0C5A32).withValues(alpha: 0.25)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? goldAccent.withValues(alpha: 0.2)
                        : const Color(0xFF0C5A32).withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.group_outlined,
                      value: '${group.assignedPersonnel.length}',
                      label: 'Total Personnel',
                      color: valueGreenColor,
                    ),
                    _VerticalDivider(),
                    _StatItem(
                      icon: Icons.category_outlined,
                      value: '${grouped.length}',
                      label: 'Categories',
                      color: goldAccent,
                    ),
                    _VerticalDivider(),
                    _StatItem(
                      icon: Icons.military_tech_outlined,
                      value: group.leaderName.split(' ').first,
                      label: 'Leader Rank',
                      color: Colors.blue.shade400,
                    ),
                  ],
                ),
              ),
            ),

            // ─── Personnel Section title ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.people_alt_outlined, color: goldAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Assigned Personnel',
                    style: TextStyle(
                      color: textThemeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Personnel List ────────────────────────────────────────
            Expanded(
              child: group.assignedPersonnel.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_off_outlined,
                              color: silverText, size: 54),
                          const SizedBox(height: 12),
                          Text(
                            'No personnel assigned',
                            style: TextStyle(color: silverText, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: assignedDetails.length,
                      itemBuilder: (context, index) {
                        final person = assignedDetails[index];
                        final rank = person['rank'] ?? '';
                        final name = person['name'] ?? '';
                        final armyNo = person['armyNo'] ?? '';
                        final cl = person['cl'] ?? '';
                        final remarks = person['remarks'] ?? '';
                        final category = person['category'] ?? '';

                        // Serial number
                        final serial = index + 1;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0C5A32).withValues(alpha: 0.12)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? goldAccent.withValues(alpha: 0.15)
                                  : const Color(0xFF0C5A32).withValues(alpha: 0.10),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF064420).withValues(alpha: 0.9),
                              ),
                              child: Center(
                                child: Text(
                                  '$serial',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              '$rank $name',
                              style: TextStyle(
                                color: textThemeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  armyNo,
                                  style: TextStyle(
                                    color: silverText,
                                    fontSize: 11,
                                  ),
                                ),
                                if (remarks.isNotEmpty)
                                  Text(
                                    remarks,
                                    style: TextStyle(
                                      color: goldAccent.withValues(alpha: 0.8),
                                      fontSize: 10.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (cl.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: valueGreenColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      cl,
                                      style: TextStyle(
                                        color: valueGreenColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (category.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color: silverText,
                                        fontSize: 9.5,
                                      ),
                                    ),
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
    );
  }
}

// ─── Helper Widgets ────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}
