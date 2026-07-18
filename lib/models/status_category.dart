class StatusCategory {
  final String id;
  final String name;
  final String? parentId;
  final int level;
  final int sortOrder;
  final String color;
  final String? icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  StatusCategory({
    required this.id,
    required this.name,
    this.parentId,
    required this.level,
    required this.sortOrder,
    this.color = '#000000',
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StatusCategory.fromJson(Map<String, dynamic> json) {
    return StatusCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
      level: json['level'] as int,
      sortOrder: json['sort_order'] as int,
      color: json['color'] as String? ?? '#000000',
      icon: json['icon'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
