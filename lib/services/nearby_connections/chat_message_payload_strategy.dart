import 'package:beacon_project/services/nearby_connections/payload_strategy.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/repositories/chat_repository.dart';
import 'package:beacon_project/repositories/chat_message_repository.dart';
import 'package:beacon_project/models/chat.dart';
import 'package:beacon_project/models/chat_message.dart';

class ChatMessagePayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase _beacon;
  final ChatRepository _chatRepository;
  final ChatMessageRepository _chatMessageRepository;

  ChatMessagePayloadStrategy(
    this._beacon,
    this._chatRepository,
    this._chatMessageRepository,
  );

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("[ChatMessage] Received from $endpointId: $data");

    final messageId = data["message_id"] as String?;
    final chatId = data["chat_id"] as String?;
    final senderUuid = data["sender_uuid"] as String?;
    final messageText = data["message"] as String?;
    final timestamp = data["timestamp"] as int?;

    if (messageId == null ||
        chatId == null ||
        senderUuid == null ||
        messageText == null ||
        timestamp == null) {
      print("[ChatMessage] Invalid payload data");
      return;
    }

    // Get or create chat
    Chat? chat = await _chatRepository.getChatById(chatId);

    if (chat == null) {
      chat = Chat(id: chatId, deviceUuid: senderUuid);
      await _chatRepository.insertChat(chat);
    }

    // Insert message (using same UUID from sender)
    final message = ChatMessage(
      id: messageId,
      chatId: chatId,
      senderUuid: senderUuid,
      messageText: messageText,
      timestamp: timestamp,
    );

    await _chatMessageRepository.insertMessage(message);

    print("[ChatMessage] Message saved to database");
  }
}
