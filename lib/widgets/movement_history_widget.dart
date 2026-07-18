import 'package:flutter/material.dart';
import '../models/movement_record.dart';
export '../models/movement_record.dart'; // Re-export for backward compatibility


class MovementHistoryWidget extends StatelessWidget {
  final List<MovementRecord> records;
  final int selectedDays;
  final ValueChanged<int>? onDaysChanged;

  const MovementHistoryWidget({
    Key? key,
    required this.records,
    this.selectedDays = 90,
    this.onDaysChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Records: ${records.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF2E3E39), // Dark green-grey
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedDays,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF2E3E39)),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF2E3E39),
                      ),
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
                        DropdownMenuItem(value: 15, child: Text('Last 15 Days')),
                        DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
                        DropdownMenuItem(value: 60, child: Text('Last 2 Months')),
                        DropdownMenuItem(value: 90, child: Text('Last 3 Months')),
                        DropdownMenuItem(value: 0, child: Text('All Time')),
                      ],
                      onChanged: onDaysChanged != null
                          ? (value) {
                              if (value != null) {
                                onDaysChanged!(value);
                              }
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200, thickness: 1),
          // Grid
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double crossAxisSpacing = 12;
                double mainAxisSpacing = 12;
                
                // Force 2 columns everywhere as requested
                double itemWidth = (constraints.maxWidth - crossAxisSpacing) / 2;
                
                return Wrap(
                  spacing: crossAxisSpacing,
                  runSpacing: mainAxisSpacing,
                  children: records.map((record) => SizedBox(
                    width: itemWidth,
                    child: _buildRecordCard(record),
                  )).toList(),
                );
              }
            ),
          ),
          // Footer info
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F5F2), // Light beige/grey background
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, color: Color(0xFF1B4D3E), size: 22), // Dark green info icon
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Individual movement history is stored for 3 months.\nMonthly snapshot reports are stored for 1 month.',
                      style: TextStyle(
                        fontSize: 13, 
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(MovementRecord record) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Stack(
        children: [
          // Timeline vertical line
          Positioned(
            left: 4, // 10px width dot / 2 - 1px line width
            top: 14, // top margin 4 + 10px dot height
            bottom: 0,
            child: Container(
              width: 2,
              color: Colors.grey.shade200,
            ),
          ),
          // Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: record.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        record.dateRange,
                        style: const TextStyle(
                          color: Color(0xFFB57E22), // brownish/gold/orange color
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        record.movement,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF2E3E39), // dark blackish-green
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            record.duration,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Example usage to show you how to render the exact data from the image:
class MovementHistoryDemoScreen extends StatelessWidget {
  const MovementHistoryDemoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Movement History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: MovementHistoryWidget(
          records: [
            MovementRecord(dateRange: '13 Apr 2026 to 13 May 2026', movement: 'Sta Gds → COM Gd', duration: '30 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '13 May 2026 to 12 Jun 2026', movement: 'Regt Emp → RP', duration: '31 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '12 Jun 2026 to 02 Jul 2026', movement: 'Present → Office', duration: '20 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '02 Jul 2026 to 03 Jul 2026', movement: 'OSL/Pris → OSL', duration: '2 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '04 Jul 2026 to 05 Jul 2026', movement: 'RP → Present', duration: '2 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '07 Jul 2026 to 09 Jul 2026', movement: 'Present → Tea Bar', duration: '3 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '10 Jul 2026 to 11 Jul 2026', movement: 'Tea Bar → Present', duration: '2 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '12 Jul 2026 to Present', movement: 'Present → RP', duration: '-', dotColor: const Color(0xFFF39C12)), // Orange dot for active
            MovementRecord(dateRange: '25 Mar 2026 to 04 Apr 2026', movement: 'COM Gd → Regt Emp', duration: '11 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '05 Apr 2026 to 12 Apr 2026', movement: 'Training → Sta Gds', duration: '8 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '15 Feb 2026 to 24 Feb 2026', movement: 'Present → Leave', duration: '9 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '25 Feb 2026 to 15 Mar 2026', movement: 'Leave → Training', duration: '18 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '10 Jan 2026 to 14 Feb 2026', movement: 'Office → Present', duration: '36 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '20 Dec 2025 to 09 Jan 2026', movement: 'RP → Office', duration: '20 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '01 Dec 2025 to 19 Dec 2025', movement: 'Course → RP', duration: '19 Days', dotColor: const Color(0xFF1B4D3E)),
            MovementRecord(dateRange: '10 Nov 2025 to 30 Nov 2025', movement: 'Leave → Course', duration: '20 Days', dotColor: const Color(0xFF1B4D3E)),
          ],
        ),
      ),
    );
  }
}
