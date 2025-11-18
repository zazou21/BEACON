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
