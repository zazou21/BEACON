import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';
import 'payload_strategy.dart';
import 'nearby_connections.dart';

class MarkOfflinePayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;

  MarkOfflinePayloadStrategy(this.beacon);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("Handling MARK_OFFLINE payload for uuid: ${data['uuid']}");

    final deviceUuid = data['uuid'] as String?;
    if (deviceUuid == null) {
      print("Error: deviceUuid is null in MARK_OFFLINE payload");
      return;
    }

    try {
      final db = await DBService().database;

      final existing = await db.query(
        'devices',
        where: 'uuid = ?',
        whereArgs: [deviceUuid],
        limit: 1,
      );

      print("Found ${existing.length} existing device(s) with uuid $deviceUuid");

      if (existing.isEmpty) {
        print("Warning: Device $deviceUuid not found in database");
        return;
      }

      // Update device status
      await db.update(
        'devices',
        {
          'isOnline': 0,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'uuid = ?',
        whereArgs: [deviceUuid],
      );

      print("Device $deviceUuid marked as offline in database");

      // Trigger state change notification
      beacon.notifyListeners();
    } catch (e) {
      print("Error handling MARK_OFFLINE payload: $e");
    }
  }
}
