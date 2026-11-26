class UserEntitlement {
  final String userId;
  final bool isPro;
  final bool isGrandfathered;
  final int maxFreeVehicles;
  final String planName;

  const UserEntitlement({
    this.userId = '',
    this.isPro = false,
    this.isGrandfathered = false,
    this.maxFreeVehicles = 2,
    this.planName = 'free',
  });

  bool get isUnlimited => isPro || isGrandfathered;

  bool canAddVehicle(int currentVehicleCount) {
    if (isUnlimited) return true;
    return currentVehicleCount < maxFreeVehicles;
  }

  factory UserEntitlement.fromJson(Map<String, dynamic> json) {
    final parsedMax = int.tryParse(json['max_free_vehicles']?.toString() ?? '2') ?? 2;
    return UserEntitlement(
      userId: json['user_id']?.toString() ?? '',
      isPro: json['is_pro'] == true,
      isGrandfathered: json['is_grandfathered'] == true,
      maxFreeVehicles: parsedMax > 0 ? parsedMax : 2,
      planName: json['plan_name']?.toString() ?? 'free',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_pro': isPro,
      'is_grandfathered': isGrandfathered,
      'max_free_vehicles': maxFreeVehicles,
      'plan_name': planName,
    };
  }
}
