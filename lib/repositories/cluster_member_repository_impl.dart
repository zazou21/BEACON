// lib/repositories/impl/cluster_member_repository_impl.dart
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'package:beacon_project/models/cluster_member.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';

class ClusterMemberRepositoryImpl implements ClusterMemberRepository {
  final DBService _dbService;

  ClusterMemberRepositoryImpl(this._dbService);

  Future<Database> get _db async => await _dbService.database;

  @override
  Future<List<ClusterMember>> getMembersByClusterId(String clusterId) async {
    final db = await _db;
    final results = await db.query(
      'cluster_members',
      where: 'clusterId = ?',
      whereArgs: [clusterId],
    );
    return results.map((map) => ClusterMember.fromMap(map)).toList();
  }

  @override
  Future<List<ClusterMember>> getMembersByDeviceUuid(String deviceUuid) async {
    final db = await _db;
    final results = await db.query(
      'cluster_members',
      where: 'deviceUuid = ?',
      whereArgs: [deviceUuid],
    );
    return results.map((map) => ClusterMember.fromMap(map)).toList();
  }

  @override
  Future<ClusterMember?> getMember(String clusterId, String deviceUuid) async {
    final db = await _db;
    final results = await db.query(
      'cluster_members',
      where: 'clusterId = ? AND deviceUuid = ?',
      whereArgs: [clusterId, deviceUuid],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ClusterMember.fromMap(results.first);
  }

  @override
  Future<void> insertMember(ClusterMember member) async {
    final db = await _db;
    await db.insert(
      'cluster_members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> deleteMember(String clusterId, String deviceUuid) async {
    final db = await _db;
    await db.delete(
      'cluster_members',
      where: 'clusterId = ? AND deviceUuid = ?',
      whereArgs: [clusterId, deviceUuid],
    );
  }

  @override
  Future<void> deleteAllMembersByDevice(String deviceUuid) async {
    final db = await _db;
    await db.delete(
      'cluster_members',
      where: 'deviceUuid = ?',
      whereArgs: [deviceUuid],
    );
  }

  @override
  Future<void> deleteAllMembersByCluster(String clusterId) async {
    final db = await _db;
    await db.delete(
      'cluster_members',
      where: 'clusterId = ?',
      whereArgs: [clusterId],
    );
  }

  @override
  Future<bool> isMemberOfCluster(String clusterId, String deviceUuid) async {
    final db = await _db;
    final results = await db.query(
      'cluster_members',
      where: 'clusterId = ? AND deviceUuid = ?',
      whereArgs: [clusterId, deviceUuid],
      limit: 1,
    );
    return results.isNotEmpty;
  }
}
