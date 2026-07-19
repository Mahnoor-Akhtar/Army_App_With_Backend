import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/personnel_data_manager.dart';

class PersonnelProfileScreen extends StatelessWidget {
  final Map<String, String> person;

  const PersonnelProfileScreen({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldAccent = isDark ? const Color(0xFFE6C200) : const Color(0xFF0C5A32);
    final silverText = isDark ? Colors.white70 : Colors.black54;
    final textThemeColor = isDark ? Colors.white : Colors.black87;

    final armyNo = person['armyNo'] ?? '';
    final rank = person['rank'] ?? '';
    final name = person['name'] ?? '';

    final manager = PersonnelDataManager();
    final status = manager.getStatus(armyNo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personnel Profile'),
        backgroundColor: goldAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: goldAccent.withValues(alpha: 0.15),
                child: ClipOval(
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: _buildAvatarImage(person['avatar'] ?? ''),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '$rank $name',
                style: TextStyle(
                  color: textThemeColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Army No: $armyNo',
                style: TextStyle(color: silverText, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            // Status section
            Text('Current Status',
                style: TextStyle(
                    color: goldAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const Divider(height: 20, thickness: 1),
            Row(
              children: [
                const Icon(Icons.category, size: 20),
                const SizedBox(width: 8),
                Text(status.category,
                    style: TextStyle(color: textThemeColor, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            if (status.subcategory != null) ...[
              Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right, size: 20),
                  const SizedBox(width: 8),
                  Text(status.subcategory!,
                      style: TextStyle(color: textThemeColor, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${status.startDate.day}/${status.startDate.month}/${status.startDate.year}${status.endDate != null
                          ? ' – ${status.endDate!.day}/${status.endDate!.month}/${status.endDate!.year}'
                          : ' – Present'}',
                  style: TextStyle(color: textThemeColor, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String avatar) {
    if (avatar.isEmpty) {
      return Image.asset(
        'assets/images/profile_avatar.jpg',
        key: const ValueKey('profile_default'),
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
          key: const ValueKey('profile_error'),
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
            key: const ValueKey('profile_net_error'),
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
}
