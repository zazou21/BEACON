import 'package:beacon_project/models/chat.dart';

abstract class ChatRepository {
  Future<Chat?> getChatByDeviceUuid(String deviceUuid);
  Future<Chat?> getChatById(String chatId);
  Future<List<Chat>> getAllChats();
  Future<void> insertChat(Chat chat);
  Future<void> deleteChat(String chatId);
}
