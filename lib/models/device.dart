class Device {
  String uuid;
  String deviceName;
  String endpointId;
  String status;

  bool isOnline;

  DateTime lastSeen;
  String lastMessage;
  DateTime createdAt;
  DateTime updatedAt;

  Device({
    required this.uuid,
    required this.deviceName,
    required this.endpointId,
    required this.status,
    this.isOnline = true, // default now TRUE
    DateTime? lastSeen,
    this.lastMessage = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lastSeen = lastSeen ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  static DateTime _parseDate(dynamic v) {
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    if (v is String) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(v)) {
        return DateTime.parse(v);
      }
      return DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    }
    throw Exception("Could not parse date field: $v");
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'deviceName': deviceName,
      'endpointId': endpointId,
      'status': status,
      'isOnline': isOnline ? 1 : 0,
      'lastSeen': lastSeen.toIso8601String(),
      'lastMessage': lastMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      uuid: map['uuid'],
      deviceName: map['deviceName'],
      endpointId: map['endpointId'],
      status: map['status'],
      isOnline: (map['isOnline'] ?? 1) == 1, // default to TRUE if missing
      lastSeen: _parseDate(map['lastSeen']),
      lastMessage: map['lastMessage'] ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }
}
