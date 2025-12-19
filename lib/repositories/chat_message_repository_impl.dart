import 'package:beacon_project/models/chat_message.dart';
import 'package:beacon_project/repositories/chat_message_repository.dart';
import 'package:beacon_project/services/db_service.dart';

class ChatMessageRepositoryImpl implements ChatMessageRepository {
  final DBService _dbService;

  ChatMessageRepositoryImpl(this._dbService);

  @override
  Future<List<ChatMessage>> getMessagesByChatId(String chatId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'chat_message',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );

    return results.map((map) => ChatMessage.fromMap(map)).toList();
  }

  @override
  Future<void> insertMessage(ChatMessage message) async {
    final db = await _dbService.database;
    await db.insert('chat_message', message.toMap());
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    final db = await _dbService.database;
    await db.delete('chat_message', where: 'id = ?', whereArgs: [messageId]);
  }

  @override
  Future<void> deleteMessagesByChatId(String chatId) async {
    final db = await _dbService.database;
    await db.delete('chat_message', where: 'chat_id = ?', whereArgs: [chatId]);
  }
}
