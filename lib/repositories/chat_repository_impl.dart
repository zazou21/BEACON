import 'package:beacon_project/models/chat.dart';
import 'package:beacon_project/repositories/chat_repository.dart';
import 'package:beacon_project/services/db_service.dart';

class ChatRepositoryImpl implements ChatRepository {
  final DBService _dbService;

  ChatRepositoryImpl(this._dbService);

  @override
  Future<Chat?> getChatByDeviceUuid(String deviceUuid) async {
    final db = await _dbService.database;
    final results = await db.query(
      'chat',
      where: 'device_uuid = ?',
      whereArgs: [deviceUuid],
    );
    if (results.isEmpty) return null;
    return Chat.fromMap(results.first);
  }

  @override
  Future<Chat?> getChatById(String chatId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'chat',
      where: 'id = ?',
      whereArgs: [chatId],
    );
    if (results.isEmpty) return null;
    return Chat.fromMap(results.first);
  }

  // New method for cluster group chat
  Future<Chat?> getChatByClusterId(String clusterId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'chat',
      where: 'cluster_id = ? AND is_group_chat = 1',
      whereArgs: [clusterId],
    );
    if (results.isEmpty) return null;
    return Chat.fromMap(results.first);
  }

  @override
  Future<List<Chat>> getAllChats() async {
    final db = await _dbService.database;
    final results = await db.query('chat');
    return results.map((map) => Chat.fromMap(map)).toList();
  }

  @override
  Future<void> insertChat(Chat chat) async {
    final db = await _dbService.database;
    await db.insert('chat', chat.toMap());
  }

  @override
  Future<void> deleteChat(String chatId) async {
    final db = await _dbService.database;
    await db.delete('chat', where: 'id = ?', whereArgs: [chatId]);
  }

  Future<void> deleteChatByClusterId(String clusterId) async {
    final db = await _dbService.database;
    await db.delete('chat', where: 'cluster_id = ?', whereArgs: [clusterId]);
  }
}
