import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
<<<<<<< HEAD
=======
          isOnline INTEGER DEFAULT 1,
          inRange INTEGER DEFAULT 1,     -- TRUE
>>>>>>> karim
          lastSeen INTEGER,
          lastMessage TEXT,
          createdAt INTEGER,
          updatedAt INTEGER
<<<<<<< HEAD
        )
=======
        )        
>>>>>>> karim
      """);

        await db.execute("""
        CREATE TABLE clusters (
          clusterId TEXT PRIMARY KEY,
          ownerUuid TEXT,
<<<<<<< HEAD
=======
          ownerEndpointId TEXT,
>>>>>>> karim
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
      },
    );
  }
}

// how to use in other screens
// import 'package:beacon_project/services/db_service.dart';

// final db = DBService();

// void loadData() async {
//   final database = await db.database;
//   final result = await database.query("ay haja");
// }
