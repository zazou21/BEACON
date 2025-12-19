import 'package:beacon_project/models/chat_message.dart';

abstract class ChatMessageRepository {
  Future<List<ChatMessage>> getMessagesByChatId(String chatId);
  Future<void> insertMessage(ChatMessage message);
  Future<void> deleteMessage(String messageId);
  Future<void> deleteMessagesByChatId(String chatId);
}
