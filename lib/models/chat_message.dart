class ChatMessage {
  String id;
  String chatId;
  String senderUuid;
  String messageText;
  int timestamp;
  DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderUuid,
    required this.messageText,
    int? timestamp,
    DateTime? createdAt,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch,
       createdAt = createdAt ?? DateTime.now();

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
      'chat_id': chatId,
      'sender_uuid': senderUuid,
      'message_text': messageText,
      'timestamp': timestamp,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      chatId: map['chat_id'],
      senderUuid: map['sender_uuid'],
      messageText: map['message_text'],
      timestamp: map['timestamp'],
      createdAt: _parseDate(map['created_at']),
    );
  }
}
