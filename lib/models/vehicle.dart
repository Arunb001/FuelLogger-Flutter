class Vehicle {
  final String id;
  final String userId;
  final String name;
  final bool isActive;
  final String iconKey;
  final String colorKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Vehicle({
    required this.id,
    required this.userId,
    required this.name,
    this.isActive = false,
    this.iconKey = 'bike',
    this.colorKey = 'red',
    this.createdAt,
    this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'My Vehicle',
      isActive: json['is_active'] == true,
      iconKey: json['icon_key']?.toString() ?? 'bike',
      colorKey: json['color_key']?.toString() ?? 'red',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'is_active': isActive,
    };
  }

  Vehicle copyWith({
    String? id,
    String? userId,
    String? name,
    bool? isActive,
    String? iconKey,
    String? colorKey,
  }) {
    return Vehicle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      iconKey: iconKey ?? this.iconKey,
      colorKey: colorKey ?? this.colorKey,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
