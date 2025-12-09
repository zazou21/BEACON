import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/profile_model.dart';

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
    return await openDatabase(
      path,
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

    
      },
    );
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

// how to use in other screens
// import 'package:beacon_project/services/db_service.dart';

// final db = DBService();

// void loadData() async {
//   final database = await db.database;
//   final result = await database.query("ay haja");
// }
