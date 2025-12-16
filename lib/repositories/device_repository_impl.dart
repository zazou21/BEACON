// lib/repositories/impl/device_repository_impl.dart
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final DBService _dbService;

  DeviceRepositoryImpl(this._dbService);

  Future<Database> get _db async => await _dbService.database;

  @override
  Future<Device?> getDeviceByUuid(String uuid) async {
    final db = await _db;
    final results = await db.query(
      'devices',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Device.fromMap(results.first);
  }

  @override
  Future<List<Device>> getAllDevices() async {
    final db = await _db;
    final results = await db.query('devices');
    return results.map((map) => Device.fromMap(map)).toList();
  }

  @override
  Future<List<Device>> getDevicesInRange() async {
    final db = await _db;
    final results = await db.query(
      'devices',
      where: 'inRange = ?',
      whereArgs: [1],
    );
    return results.map((map) => Device.fromMap(map)).toList();
  }

  @override
  Future<List<Device>> getDevicesByUuids(List<String> uuids) async {
    if (uuids.isEmpty) return [];
    final db = await _db;
    final placeholders = List.filled(uuids.length, '?').join(',');
    final results = await db.query(
      'devices',
      where: 'uuid IN ($placeholders)',
      whereArgs: uuids,
    );
    return results.map((map) => Device.fromMap(map)).toList();
  }

  @override
  Future<void> insertDevice(Device device) async {
    final db = await _db;
    await db.insert(
      'devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateDevice(Device device) async {
    final db = await _db;
    await db.update(
      'devices',
      device.toMap(),
      where: 'uuid = ?',
      whereArgs: [device.uuid],
    );
  }

  @override
  Future<void> updateDeviceStatus(String uuid, String status) async {
    final db = await _db;
    await db.update(
      'devices',
      {
        'status': status,
        'lastSeen': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  @override
  Future<void> markDeviceOnline(String uuid) async {
    final db = await _db;
    await db.update(
      'devices',
      {
        'isOnline': 1,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  @override
  Future<void> markDeviceOffline(String uuid) async {
    final db = await _db;
    await db.update(
      'devices',
      {
        'isOnline': 0,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  @override
  Future<void> updateDeviceInRange(String uuid, bool inRange) async {
    final db = await _db;
    await db.update(
      'devices',
      {
        'inRange': inRange ? 1 : 0,
        'lastSeen': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  @override
  Future<void> updateDeviceEndpoint(String uuid, String endpointId) async {
    final db = await _db;
    await db.update(
      'devices',
      {
        'endpointId': endpointId,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  @override
  Future<void> deleteDevice(String uuid) async {
    final db = await _db;
    await db.delete(
      'devices',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  @override
  Future<List<Device>> getDevicesNotInCluster(String clusterId, String excludeUuid) async {
    final db = await _db;
    final results = await db.query(
      'devices',
      where: '''
        inRange = ? 
        AND uuid != ? 
        AND uuid NOT IN (
          SELECT deviceUuid FROM cluster_members WHERE clusterId = ?
        )
      ''',
      whereArgs: [1, excludeUuid, clusterId],
    );
    return results.map((map) => Device.fromMap(map)).toList();
  }
}
