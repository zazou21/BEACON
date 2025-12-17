// lib/repositories/impl/cluster_repository_impl.dart
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';

class ClusterRepositoryImpl implements ClusterRepository {
  final DBService _dbService;

  ClusterRepositoryImpl(this._dbService);

  Future<Database> get _db async => await _dbService.database;

  @override
  Future<Cluster?> getClusterById(String clusterId) async {
    final db = await _db;
    final results = await db.query(
      'clusters',
      where: 'clusterId = ?',
      whereArgs: [clusterId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Cluster.fromMap(results.first);
  }

  @override
  Future<List<Cluster>> getAllClusters() async {
    final db = await _db;
    final results = await db.query('clusters');
    return results.map((map) => Cluster.fromMap(map)).toList();
  }

  @override
  Future<Cluster?> getClusterByOwnerUuid(String ownerUuid) async {
    final db = await _db;
    final results = await db.query(
      'clusters',
      where: 'ownerUuid = ?',
      whereArgs: [ownerUuid],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Cluster.fromMap(results.first);
  }

  @override
  Future<void> insertCluster(Cluster cluster) async {
    final db = await _db;
    await db.insert(
      'clusters',
      cluster.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateCluster(Cluster cluster) async {
    final db = await _db;
    await db.update(
      'clusters',
      cluster.toMap(),
      where: 'clusterId = ?',
      whereArgs: [cluster.clusterId],
    );
  }

  @override
  Future<void> deleteCluster(String clusterId) async {
    final db = await _db;
    await db.delete(
      'clusters',
      where: 'clusterId = ?',
      whereArgs: [clusterId],
    );
  }

  @override
  Future<void> deleteClusterByOwner(String ownerUuid) async {
    final db = await _db;
    await db.delete(
      'clusters',
      where: 'ownerUuid = ?',
      whereArgs: [ownerUuid],
    );
  }
}
