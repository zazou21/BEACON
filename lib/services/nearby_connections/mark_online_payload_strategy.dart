import 'payload_strategy.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';
import 'nearby_connections.dart';

class MarkOnlinePayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;

  MarkOnlinePayloadStrategy(this.beacon);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("Handling MARK_ONLINE payload for endpointId: $endpointId");

    final deviceUuid = data['uuid'] as String?;
    if (deviceUuid == null) {
      print("Error: deviceUuid is null in MARK_ONLINE payload");
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
          'isOnline': 1,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'uuid = ?',
        whereArgs: [deviceUuid],
      );

      print("Device $deviceUuid marked as online in database");

      // Trigger state change notification
      beacon.notifyListeners();
    } catch (e) {
      print("Error handling MARK_ONLINE payload: $e");
    }
  }
}
