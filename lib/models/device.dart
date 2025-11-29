class Device {
  String uuid;
  String deviceName;
  String endpointId;
  String status;
<<<<<<< HEAD

  bool isOnline;
  bool inRange;

=======
>>>>>>> ezz
  DateTime lastSeen;
  String lastMessage;
  DateTime createdAt;
  DateTime updatedAt;

  Device({
    required this.uuid,
    required this.deviceName,
    required this.endpointId,
    required this.status,
    this.isOnline = true,
    this.inRange = true,
    DateTime? lastSeen,
    this.lastMessage = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lastSeen = lastSeen ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  static DateTime _parseDate(dynamic v) {
<<<<<<< HEAD
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(v)) {
        return DateTime.parse(v);
      }
=======
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    if (v is String) {
      // ISO-8601 datetime → parse directly
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(v)) {
        return DateTime.parse(v);
      }
      // numeric string → millis
>>>>>>> ezz
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
<<<<<<< HEAD
      'isOnline': isOnline ? 1 : 0,
      'inRange': inRange ? 1 : 0,
=======
      // store ISO-8601 (consistent)
>>>>>>> ezz
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
<<<<<<< HEAD
      isOnline: (map['isOnline'] ?? 1) == 1,
      inRange: (map['inRange'] ?? 1) == 1, // default TRUE
=======
>>>>>>> ezz
      lastSeen: _parseDate(map['lastSeen']),
      lastMessage: map['lastMessage'] ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }
}
