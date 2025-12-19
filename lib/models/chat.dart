class Chat {
  String id;
  String? deviceUuid; // nullable for group chats
  String? clusterId; // new field for cluster group chats
  bool isGroupChat; // flag to distinguish between private and group
  DateTime createdAt;

  Chat({
    required this.id,
    this.deviceUuid,
    this.clusterId,
    this.isGroupChat = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    // Validation: either deviceUuid OR clusterId must be set
    assert(
      (deviceUuid != null && clusterId == null) ||
          (deviceUuid == null && clusterId != null),
      'Chat must have either deviceUuid or clusterId, not both',
    );
  }

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
      'cluster_id': clusterId,
      'is_group_chat': isGroupChat ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      deviceUuid: map['device_uuid'],
      clusterId: map['cluster_id'],
      isGroupChat: map['is_group_chat'] == 1,
      createdAt: _parseDate(map['created_at']),
    );
  }
}
