import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/device.dart';
import 'payload_strategy.dart';
import 'nearby_connections.dart';

class ClusterInfoPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  ClusterInfoPayloadStrategy(this.beacon);
  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("Handling CLUSTER_INFO payload for endpointId: $endpointId");
    final clusterId = data['clusterId'] as String?;
    final devices = data['devices'] as List<dynamic>?;
    final members = data['members'] as List<dynamic>?;

    if (clusterId == null || devices == null || members == null) return;

    final joinerUuid = await _getDeviceUUID();
    final db = await DBService().database;

    // Save devices
    for (final d in devices) {
      final deviceMap = Map<String, dynamic>.from(d);

      // skip joiner's own device
      if (deviceMap['uuid'] == joinerUuid) continue;

      //popule endpoint for sender
      if (deviceMap['uuid'] == data['senderUuid']) {
        deviceMap['endpointId'] = endpointId;
      }

      final existing = await db.query(
        'devices',
        where: 'uuid = ?',
        whereArgs: [deviceMap['uuid']],
      );

      final device = Device(
        uuid: deviceMap['uuid'],
        deviceName: deviceMap['deviceName'] ?? "Unknown",
        endpointId: deviceMap['endpointId'] ?? '',
        status: "Connected",
        lastSeen: DateTime.now(),
      );

      if (existing.isNotEmpty) {
        await db.update(
          'devices',
          device.toMap(),
          where: 'uuid = ?',
          whereArgs: [device.uuid],
        );
      } else {
        await db.insert(
          'devices',
          device.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // Save cluster_members
    for (final m in members) {
      final memberMap = Map<String, dynamic>.from(m);

      // skip joiner's own
      if (memberMap['deviceUuid'] == joinerUuid) continue;

      await db.insert('cluster_members', {
        'clusterId': memberMap['clusterId'],
        'deviceUuid': memberMap['deviceUuid'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    beacon.onClusterInfoSent?.call();
  }

  Future<String> _getDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString('device_uuid');
    if (stored == null) {
      stored = const Uuid().v4();
      await prefs.setString('device_uuid', stored);
    }
    return stored;
  }
}
