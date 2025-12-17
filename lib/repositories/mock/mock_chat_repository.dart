import '../chat_repository.dart';
import '../../models/chat.dart';

//  Future<Chat?> getChatByDeviceUuid(String deviceUuid);
//   Future<Chat?> getChatById(String chatId);
//   Future<List<Chat>> getAllChats();
//   Future<void> insertChat(Chat chat);
//   Future<void> deleteChat(String chatId);

class MockChatRepository implements ChatRepository {

  List<Chat>? mockChats;
  MockChatRepository({this.mockChats});



  @override
  Future<Chat?> getChatByDeviceUuid(String deviceUuid) async {
    if (mockChats == null) return null;
    try {
      return mockChats!.firstWhere(
        (chat) => chat.deviceUuid.contains(deviceUuid),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Chat?> getChatById(String chatId) async {
    if (mockChats == null) return null;
    try {
      return mockChats!.firstWhere(
        (chat) => chat.id.contains(chatId),
      );
    } catch (e) {}
    return null;
  }

  @override
  Future<List<Chat>> getAllChats() async {
    if (mockChats != null) {
      return mockChats!;
    }
    return [];
  }

  @override
  Future<void> insertChat(Chat chat) async {
    if (mockChats != null) {
      mockChats!.add(chat);
    }
  }

  @override
  Future<void> deleteChat(String chatId) async {
    if (mockChats != null) {
      mockChats!.removeWhere((chat) => chat.id == chatId);
    }
  }





  
}