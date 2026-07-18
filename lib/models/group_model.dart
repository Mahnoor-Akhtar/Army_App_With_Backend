/// Data model representing a custom dynamic group of personnel.
class GroupModel {
  final String id;
  final String name;
  final String category;
  final String leaderArmyNo;
  final String leaderName;
  final String location;
  final List<String> assignedPersonnel; // List of armyNo
  final DateTime untilDate;

  GroupModel({
    required this.id,
    required this.name,
    required this.category,
    required this.leaderArmyNo,
    required this.leaderName,
    required this.location,
    required this.assignedPersonnel,
    required this.untilDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'leaderArmyNo': leaderArmyNo,
        'leaderName': leaderName,
        'location': location,
        'assignedPersonnel': assignedPersonnel,
        'untilDate': untilDate.toIso8601String(),
      };

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        leaderArmyNo: json['leaderArmyNo'] as String? ?? '',
        leaderName: json['leaderName'] as String? ?? '',
        location: json['location'] as String? ?? '',
        assignedPersonnel: List<String>.from(json['assignedPersonnel'] ?? []),
        untilDate: DateTime.parse(json['untilDate'] as String),
      );

  GroupModel copyWith({
    String? id,
    String? name,
    String? category,
    String? leaderArmyNo,
    String? leaderName,
    String? location,
    List<String>? assignedPersonnel,
    DateTime? untilDate,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      leaderArmyNo: leaderArmyNo ?? this.leaderArmyNo,
      leaderName: leaderName ?? this.leaderName,
      location: location ?? this.location,
      assignedPersonnel: assignedPersonnel ?? this.assignedPersonnel,
      untilDate: untilDate ?? this.untilDate,
    );
  }
}
