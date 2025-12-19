import '../chat_message_repository.dart';
import '../../models/chat_message.dart';

//  Future<List<ChatMessage>> getMessagesByChatId(String chatId);
//   Future<void> insertMessage(ChatMessage message);
//   Future<void> deleteMessage(String messageId);
//   Future<void> deleteMessagesByChatId(String chatId);

class MockChatMessageRepository implements ChatMessageRepository {
  List<ChatMessage>? mockMessages;

  MockChatMessageRepository({this.mockMessages});

  @override
  Future<List<ChatMessage>> getMessagesByChatId(String chatId) async {
    if (mockMessages == null) return [];
    return mockMessages!
        .where((message) => message.chatId.contains(chatId))
        .toList();
  }

  @override
  Future<void> insertMessage(ChatMessage message) async {
    if (mockMessages != null) {
      mockMessages!.add(message);
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    if (mockMessages != null) {
      mockMessages!.removeWhere((message) => message.id == messageId);
    }
  }

  @override
  Future<void> deleteMessagesByChatId(String chatId) {
    if (mockMessages != null) {
      mockMessages!.removeWhere((message) => message.chatId == chatId);
    }
    return Future.value();
  }
}