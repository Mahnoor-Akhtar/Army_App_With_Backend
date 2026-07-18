class StatusHistory {
  final String id;
  final String armyNo;
  final String category;
  final String? subcategory;
  final String? subSubcategory;
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
    this.subSubcategory,
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
    return StatusHistory(
      id: json['id'] as String,
      armyNo: json['army_no'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      subSubcategory: json['sub_subcategory'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      destination: json['destination'] as String?,
      remarks: json['remarks'] as String?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
