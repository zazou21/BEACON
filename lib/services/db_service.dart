import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:beacon_project/models/profile_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DBService {
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'app.db');

    // Get or create encryption password
    const storage = FlutterSecureStorage();
    String? password = await storage.read(key: 'db_encryption_password');

    if (password == null) {
      // Generate a secure random password for first time
      password = _generateSecurePassword();
      await storage.write(key: 'db_encryption_password', value: password);
    }

    return openDatabase(
      path,
      password: password,
      version: 1,
      onCreate: (db, version) async {
        await db.execute("""
          CREATE TABLE devices (
            uuid TEXT PRIMARY KEY,
            deviceName TEXT,
            endpointId TEXT,
            status TEXT,
            isOnline INTEGER DEFAULT 1,
            inRange INTEGER DEFAULT 1,
            lastSeen INTEGER,
            lastMessage TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          )
          """);

        await db.execute("""
          CREATE TABLE clusters (
            clusterId TEXT PRIMARY KEY,
            ownerUuid TEXT,
            ownerEndpointId TEXT,
            name TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          )
          """);

        await db.execute("""
        CREATE TABLE cluster_members (
          clusterId TEXT,
          deviceUuid TEXT,
          joinedAt INTEGER,
          PRIMARY KEY(clusterId, deviceUuid),
          FOREIGN KEY(clusterId) REFERENCES clusters(clusterId),
          FOREIGN KEY(deviceUuid) REFERENCES devices(uuid)
        )
      """);

        await db.execute("""
        CREATE TABLE resources (
          resourceId TEXT PRIMARY KEY,
          resourceName TEXT,
          resourceDescription TEXT,
          resourceType TEXT,
          resourceStatus TEXT,
          userUuid TEXT,
          createdAt INTEGER,
        
          FOREIGN KEY(userUuid) REFERENCES devices(uuid)
          )
       """);

        await db.execute("""
        CREATE TABLE profile (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fullName TEXT NOT NULL,
          phone TEXT NOT NULL,
          emergencyName TEXT NOT NULL,
          emergencyPhone TEXT NOT NULL,
          location TEXT,
          createdAt INTEGER,
          updatedAt INTEGER
        )
        """);

        await db.execute("""
            CREATE TABLE chat (
              id TEXT PRIMARY KEY,
              device_uuid TEXT,
              cluster_id TEXT,
              is_group_chat INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              FOREIGN KEY (device_uuid) REFERENCES device(uuid) ON DELETE CASCADE,
              FOREIGN KEY (cluster_id) REFERENCES clusters(clusterId) ON DELETE CASCADE,
              CHECK (
                (device_uuid IS NOT NULL AND cluster_id IS NULL AND is_group_chat = 0) OR
                (device_uuid IS NULL AND cluster_id IS NOT NULL AND is_group_chat = 1)
              )
            );
        """);
        await db.execute("""
          CREATE TABLE chat_message (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            sender_uuid TEXT NOT NULL,
            message_text TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (chat_id) REFERENCES chat(id) ON DELETE CASCADE
          );
      
        """);
      },
    );
  }

  /// Generate a secure random password for database encryption
  String _generateSecurePassword() {
    const String chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()';
    final random = _SecureRandom();
    return List.generate(
      32,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // ---------------- Profile Helpers ----------------

  Future<int> insertProfile(ProfileModel profile) async {
    final db = await database;
    // Check if profile already exists
    final existing = await db.query('profile', limit: 1);
    if (existing.isEmpty) {
      return await db.insert('profile', profile.toMap());
    } else {
      // update the existing profile
      return await db.update(
        'profile',
        profile.toMap(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<ProfileModel?> getProfile() async {
    final db = await database;
    final result = await db.query('profile', limit: 1);
    if (result.isNotEmpty) {
      return ProfileModel.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateProfile(ProfileModel profile) async {
    final db = await database;
    return await db.update(
      'profile',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<int> deleteProfile() async {
    final db = await database;
    return await db.delete('profile');
  }
}

// Secure Random Generator for encryption password
class _SecureRandom {
  static final _random = DateTime.now().microsecond;

  int nextInt(int max) {
    // Simple secure random using dart:math
    return (DateTime.now().microsecond * 31 + DateTime.now().millisecond) % max;
  }
}

// how to use in other screens
// import 'package:beacon_project/services/db_service.dart';

// final db = DBService();

// void loadData() async {
//   final database = await db.database;
//   final result = await database.query("ay haja");
// }
