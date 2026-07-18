class Personnel {
  final String armyNo;
  final String? profilePhoto;
  final String fightingStatus;
  final String rank;
  final String name;
  final String trade;
  final String category;
  final String cl;
  final String battery;
  final String? phoneNumber;
  final String? city;
  final String? remarks;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Personnel({
    required this.armyNo,
    this.profilePhoto,
    required this.fightingStatus,
    required this.rank,
    required this.name,
    required this.trade,
    required this.category,
    required this.cl,
    required this.battery,
    this.phoneNumber,
    this.city,
    this.remarks,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Personnel.fromJson(Map<String, dynamic> json) {
    return Personnel(
      armyNo: json['army_no'] as String,
      profilePhoto: json['profile_photo'] as String?,
      fightingStatus: json['fighting_status'] as String,
      rank: json['rank'] as String,
      name: json['name'] as String,
      trade: json['trade'] as String,
      category: json['category'] as String,
      cl: json['cl'] as String,
      battery: json['battery'] as String,
      phoneNumber: json['phone_number'] as String?,
      city: json['city'] as String?,
      remarks: json['remarks'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'army_no': armyNo,
      'profile_photo': profilePhoto,
      'fighting_status': fightingStatus,
      'rank': rank,
      'name': name,
      'trade': trade,
      'category': category,
      'cl': cl,
      'battery': battery,
      'phone_number': phoneNumber,
      'city': city,
      'remarks': remarks,
      'is_active': isActive,
    };
  }
}
