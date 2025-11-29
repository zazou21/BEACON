// cluster_info_payload_strategy.dart
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

    if (clusterId == null || devices == null || members == null) {
      print("Error: Missing required fields in CLUSTER_INFO payload");
      return;
    }

    try {
      final joinerUuid = await _getDeviceUUID();
      final db = await DBService().database;

      // Save devices (robust conversions)
      for (final d in devices) {
        final deviceMap = Map<String, dynamic>.from(d);

        // Skip joiner's own device
        if (deviceMap['uuid'] == joinerUuid) continue;

        // If this device is the sender, populate endpointId we received connection from
        if (deviceMap['uuid'] == data['senderUuid']) {
          deviceMap['endpointId'] = endpointId;
        }

        // normalize isOnline (accept 1/0 or true/false)
        final bool isOnline =
            deviceMap['isOnline'] == 1 || deviceMap['isOnline'] == true;

        final existing = await db.query(
          'devices',
          where: 'uuid = ?',
          whereArgs: [deviceMap['uuid']],
          limit: 1,
        );

        final device = Device(
          uuid: deviceMap['uuid'],
          deviceName: deviceMap['deviceName'] ?? "Unknown",
          endpointId: deviceMap['endpointId'] ?? '',
          status: deviceMap['status'] ?? "Connected",
          lastSeen: DateTime.now(),
          isOnline: isOnline,
          inRange: deviceMap['inRange'] == 1 || deviceMap['inRange'] == true,
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

      print("Saved ${devices.length} devices to database");

      // Save cluster_members
      for (final m in members) {
        final memberMap = Map<String, dynamic>.from(m);

        // Skip joiner's own membership
        if (memberMap['deviceUuid'] == joinerUuid) continue;

        await db.insert('cluster_members', {
          'clusterId': memberMap['clusterId'],
          'deviceUuid': memberMap['deviceUuid'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      print("Saved ${members.length} cluster members to database");

      // Trigger state change notification for UI update
      beacon.notifyListeners();
    } catch (e) {
      print("Error handling CLUSTER_INFO payload: $e");
    }
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
