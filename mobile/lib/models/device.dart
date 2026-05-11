class Device {
  final int id;
  final String name;
  final String deviceType;
  final String platform;
  final bool isOnline;
  final String? lastSeen;
  final String createdAt;

  Device({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.platform,
    required this.isOnline,
    this.lastSeen,
    required this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      name: json['name'] as String,
      deviceType: json['device_type'] as String? ?? json['type'] as String? ?? 'unknown',
      platform: json['platform'] as String? ?? 'unknown',
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen_at'] as String? ?? json['last_seen'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'device_type': deviceType,
        'platform': platform,
      };
}
