import 'package:flutter/foundation.dart';
import '../services/personnel_data.dart';
import '../services/personnel_data_manager.dart';

/// ViewModel for the Battery Detail screen.
/// Manages search query, filter category, and all computed data
/// (filtered personnel list + strength stats).
/// Helper logic extracted from _BatteryDetailScreenState.
class BatteryDetailViewModel extends ChangeNotifier {
  final String batteryKey;

  String _searchQuery = '';
  String _filterCategory = 'All';

  BatteryDetailViewModel({required this.batteryKey});

  // ── Getters ─────────────────────────────────────────────────────────────

  String get searchQuery => _searchQuery;
  String get filterCategory => _filterCategory;

  // ── Setters ──────────────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void setFilterCategory(String category) {
    _filterCategory = category;
    notifyListeners();
  }

  // ── Computed data ────────────────────────────────────────────────────────

  List<Map<String, String>> get batteryPersonnel =>
      nominalRollList.where((p) => _getBattery(p) == batteryKey).toList();

  List<Map<String, String>> get filteredPersonnel {
    return batteryPersonnel.where((p) {
      final name = (p['name'] ?? '').toLowerCase();
      final rank = (p['rank'] ?? '').toLowerCase();
      final armyNo = (p['armyNo'] ?? '').toLowerCase();
      final matchQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          rank.contains(_searchQuery) ||
          armyNo.contains(_searchQuery);

      if (!matchQuery) return false;
      if (_filterCategory == 'All') return true;

      final isFighting = this.isFighting(p);
      if (_filterCategory == 'Non-Fighting') return !isFighting;

      final selectedRank = _filterCategory.trim();

      if (['Clk', 'Ck', 'Civ', 'LAD', 'NCB', 'S/W', 'Engr', 'N/A']
          .contains(selectedRank)) {
        return !isFighting &&
            getTrade(p).toLowerCase() == selectedRank.toLowerCase();
      }

      final subcat = getRankSubcategory(p['rank'] ?? '', p['name'] ?? '');
      final cat = getRankCategory(p['rank'] ?? '', p['name'] ?? '');

      if (selectedRank == 'Officers') {
        return isFighting && cat == 'OFFICERS';
      } else if (selectedRank == 'JCOs') {
        return isFighting && cat == 'JCOs';
      } else if (selectedRank == 'Sldrs' ||
          selectedRank == 'Soldiers' ||
          selectedRank == 'SLDRS') {
        return isFighting && cat == 'SLDRS';
      } else {
        if (subcat.toLowerCase() != selectedRank.toLowerCase()) return false;
        return isFighting;
      }
    }).toList();
  }

  Map<String, int> get stats {
    int total = 0, officers = 0, jcos = 0, sldrs = 0, nonFighting = 0;
    for (final p in batteryPersonnel) {
      total++;
      if (!isFighting(p)) {
        nonFighting++;
      } else {
        final cat = getRankCategory(p['rank'] ?? '', p['name'] ?? '');
        if (cat == 'OFFICERS') {
          officers++;
        } else if (cat == 'JCOs') {
          jcos++;
        } else {
          sldrs++;
        }
      }
    }
    return {
      'total': total,
      'officers': officers,
      'jcos': jcos,
      'sldrs': sldrs,
      'nonFighting': nonFighting,
    };
  }

  // ── Status helpers ───────────────────────────────────────────────────────

  String getStatus(Map<String, String> p) =>
      PersonnelDataManager().getStatus(p['armyNo'] ?? '').category;

  // ── Personnel classification helpers ────────────────────────────────────
  // These are duplicated from DashboardScreen / BatteryDetailScreen.

  bool isFighting(Map<String, String> person) {
    if (person['isFighting'] == 'false') return false;
    if (person['isFighting'] == 'true') return true;
    final category = (person['category'] ?? '').toLowerCase();
    final combined =
        '${person['rank'] ?? ''} ${person['name'] ?? ''}'.toLowerCase();
    if (category == 'clks' ||
        category == 'c/us' ||
        category == 'sws' ||
        category == 's/ws' ||
        category == 'ncbs' ||
        category == 'civs' ||
        category == 'lads') return false;
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
        combined.contains('s/w')) return false;
    return true;
  }

  String getTrade(Map<String, String> person) {
    final category = (person['category'] ?? '').toLowerCase();
    final rank = (person['rank'] ?? '').toLowerCase();
    final name = (person['name'] ?? '').toLowerCase();
    final combined = '$rank $name'.toLowerCase();

    if (category == 'clks' || combined.contains('clk')) return 'Clk';
    if (category == 'ncbs' || combined.contains('ncb')) return 'NCB';
    if (category == 'sws' ||
        combined.contains('sw') ||
        combined.contains('s/w')) return 'S/W';
    if (category == 'c/us' ||
        combined.contains('ck') ||
        combined.contains('c/u') ||
        combined.contains('c/m')) return 'Ck';
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
        combined.contains('sry')) return 'Svy';
    if (category == 'tas' || combined.contains('ta')) return 'TA';
    if (category == 'ocsu' || combined.contains('ocu')) return 'OCU';
    if (category == 'dsvs' || combined.contains('dsv')) return 'DSV';
    if (category == 'dmts' || combined.contains('dmt')) return 'DMT';
    if (category == 'gnrs' || combined.contains('gnr')) return 'Gnr';

    return 'Gnr';
  }

  String getRankSubcategory(String rank, String name) {
    final r = rank.trim().toLowerCase();
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
    if (r == 'sm' || r == 'subedar major') return 'SM';
    if (r == 'n/sub' ||
        r == 'n-sub' ||
        r == 'naib subedar' ||
        r.contains('n/sub')) return 'N/Sub';
    if (r == 'sub' || r == 'subedar') return 'Sub';
    if (r.contains('hav') ||
        r.contains('bqmh') ||
        r.contains('rqmh') ||
        r == 'havildar') return 'Hav';
    if (r == 'lhav' ||
        r == 'lhv' ||
        r == 'lance havildar' ||
        r.contains('lhav') ||
        r.contains('lhv')) return 'Lhav';
    if (r == 'lnk' ||
        r == 'l/nk' ||
        r == 'lance naik' ||
        r.contains('lnk') ||
        r.contains('l/nk')) return 'Lnk';
    if (r == 'nk' || r == 'naik' || r == 'nco' || r.contains('nk')) {
      return 'Nk';
    }
    return 'Sep';
  }

  String getRankCategory(String rank, String name) {
    final sub = getRankSubcategory(rank, name);
    if (['Lt Col', 'Maj', 'Capt', 'Lt', '2/Lt'].contains(sub)) {
      return 'OFFICERS';
    }
    if (['SM', 'Sub', 'N/Sub'].contains(sub)) return 'JCOs';
    return 'SLDRS';
  }

  String getBattery(Map<String, String> person) {
    if (person['battery'] != null && person['battery']!.isNotEmpty) {
      return person['battery']!;
    }
    final armyNo = person['armyNo'] ?? '';
    if (armyNo == 'NYA' || armyNo.isEmpty) return 'HQ Bty';
    final cleanNo = armyNo.replaceAll(RegExp(r'\D'), '');
    if (cleanNo.isEmpty) return 'HQ Bty';
    final lastDigit = int.tryParse(cleanNo[cleanNo.length - 1]) ?? 0;
    if (lastDigit == 0 || lastDigit == 4) return 'HQ Bty';
    if (lastDigit == 1 || lastDigit == 5) return 'P Bty';
    if (lastDigit == 2 || lastDigit == 6 || lastDigit == 8) return 'Q Bty';
    return 'R Bty';
  }

  String _getBattery(Map<String, String> person) => getBattery(person);
}
