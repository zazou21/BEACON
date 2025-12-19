import 'package:beacon_project/repositories/profile_repository.dart';
import 'package:beacon_project/models/profile_model.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final DBService _dbService;

  ProfileRepositoryImpl(this._dbService);

  Future<Database> get _db async => await _dbService.database;

  @override
  Future<ProfileModel?> getProfile() async {
    final db = await _db;
    final results = await db.query(
      'profile',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ProfileModel.fromMap(results.first);
  }

  @override
  Future<void> insertProfile(ProfileModel profile) async {
    final db = await _db;
    await db.insert(
      'profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateProfile(ProfileModel profile) async {
    final db = await _db;
    await db.update(
      'profile',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  @override
  Future<void> deleteProfile() async {
    final db = await _db;
    await db.delete('profile');
  }
}
