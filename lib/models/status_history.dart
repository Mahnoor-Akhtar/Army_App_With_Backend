class StatusHistory {
  final String id;
  final String armyNo;
  final String category;
  final String? subcategory;
  final DateTime startDate;
  final DateTime? endDate;
  final String? destination;
  final String? remarks;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  StatusHistory({
    required this.id,
    required this.armyNo,
    required this.category,
    this.subcategory,
    required this.startDate,
    this.endDate,
    this.destination,
    this.remarks,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    DateTime? parsedEndDate;
    if (json['end_date'] != null) {
      parsedEndDate = DateTime.parse(json['end_date'] as String);
    } else if (json['remarks'] != null) {
      final remarksStr = json['remarks'] as String;
      final match = RegExp(r'Planned return: (\d{4}-\d{2}-\d{2})').firstMatch(remarksStr);
      if (match != null) {
        parsedEndDate = DateTime.tryParse(match.group(1)!);
      }
    }

    return StatusHistory(
      id: json['id'] as String,
      armyNo: json['army_no'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: parsedEndDate,
      destination: json['destination'] as String?,
      remarks: json['remarks'] as String?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
