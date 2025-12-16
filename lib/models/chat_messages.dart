class ChatMessage {
  String chatId;
  String id;              
  String senderUuid;     
  String receiverUuid;    
  String? clusterId;     
  String content; 


  bool isOutgoing;      
  bool isDelivered;       
  bool isRead;           

  DateTime createdAt;     
  DateTime? deliveredAt; 
  DateTime? readAt;       

  ChatMessage({
    required this.chatId,
    required this.id,
    required this.senderUuid,
    required this.receiverUuid,
    this.clusterId,
    required this.content,
    this.isOutgoing = false,
    this.isDelivered = false,
    this.isRead = false,
    DateTime? createdAt,
    this.deliveredAt,
    this.readAt,
  }) : createdAt = createdAt ?? DateTime.now();

 

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

  static DateTime? _parseNullableDate(dynamic v) {
    if (v == null) return null;
    return _parseDate(v);
  }

  // ---------- Map <-> Model ----------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUuid': senderUuid,
      'receiverUuid': receiverUuid,
      'clusterId': clusterId,
      'content': content,
      'isOutgoing': isOutgoing ? 1 : 0,
      'isDelivered': isDelivered ? 1 : 0,
      'isRead': isRead ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      chatId:map['chatId'],
      id: map['id'],
      senderUuid: map['senderUuid'],
      receiverUuid: map['receiverUuid'],
      clusterId: map['clusterId'],
      content: map['content'],
      isOutgoing: (map['isOutgoing'] ?? 0) == 1,
      isDelivered: (map['isDelivered'] ?? 0) == 1,
      isRead: (map['isRead'] ?? 0) == 1,
      createdAt: _parseDate(map['createdAt']),
      deliveredAt: _parseNullableDate(map['deliveredAt']),
      readAt: _parseNullableDate(map['readAt']),
    );
  }
}
