class Chat {
  String id;
  String deviceUuid;
  DateTime createdAt;

  Chat({required this.id, required this.deviceUuid, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  static DateTime _parseDate(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
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
      'id': id,
      'device_uuid': deviceUuid,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      deviceUuid: map['device_uuid'],
      createdAt: _parseDate(map['created_at']),
    );
  }
}
