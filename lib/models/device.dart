class Device {
  String uuid;
  String deviceName;
  String endpointId;
  String status; // 'Connected', 'Available', etc.
  DateTime lastSeen;
  String lastMessage;
  DateTime createdAt;
  DateTime updatedAt;

  Device({
    required this.uuid,
    required this.deviceName,
    required this.endpointId,
    required this.status,
    DateTime? lastSeen,
    this.lastMessage = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : lastSeen = lastSeen ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'deviceName': deviceName,
      'endpointId': endpointId,
      'status': status,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'lastMessage': lastMessage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      uuid: map['uuid'],
      deviceName: map['deviceName'],
      endpointId: map['endpointId'],
      status: map['status'],
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen']),
      lastMessage: map['lastMessage'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
    );
  }
}
