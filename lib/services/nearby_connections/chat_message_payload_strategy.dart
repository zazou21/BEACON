import 'package:beacon_project/services/nearby_connections/payload_strategy.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/repositories/chat_repository.dart';
import 'package:beacon_project/repositories/chat_message_repository.dart';
import 'package:beacon_project/models/chat.dart';
import 'package:beacon_project/models/chat_message.dart';
import 'package:beacon_project/services/notification_service.dart';

class ChatMessagePayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  final ChatRepository chatRepository;
  final ChatMessageRepository chatMessageRepository;
  final NotificationService _notificationService = NotificationService();

  ChatMessagePayloadStrategy(
    this.beacon,
    this.chatRepository,
    this.chatMessageRepository,
  );

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print('ChatMessage: Received from $endpointId: $data');

    final messageId = data['messageid'] as String?;
    final chatId = data['chatid'] as String?;
    final senderUuid = data['senderuuid'] as String?;
    final messageText = data['message'] as String?;
    final timestamp = data['timestamp'] as int?;

    if (messageId == null ||
        chatId == null ||
        senderUuid == null ||
        messageText == null ||
        timestamp == null) {
      print('ChatMessage: Invalid payload data');
      return;
    }

    // Get or create chat
    Chat? chat = await chatRepository.getChatById(chatId);
    if (chat == null) {
      chat = Chat(id: chatId, deviceUuid: senderUuid);
      await chatRepository.insertChat(chat);
    }

    // Insert message
    final message = ChatMessage(
      id: messageId,
      chatId: chatId,
      senderUuid: senderUuid,
      messageText: messageText,
      timestamp: timestamp,
    );
    await chatMessageRepository.insertMessage(message);
    print('ChatMessage: Message saved to database');

    // Get device info for notification
    final device = await beacon.deviceRepository?.getDeviceByUuid(senderUuid);
    final deviceName = device?.deviceName ?? 'Unknown Device';

    // Show notification
    await _notificationService.showChatNotification(
      deviceUuid: senderUuid,
      deviceName: deviceName,
      message: messageText,
    );
  }
}
