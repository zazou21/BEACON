import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';
import 'payload_strategy.dart';
import 'nearby_connections.dart';

class MarkOfflinePayloadStrategy implements PayloadStrategy {
  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("Handling MARK_OFFLINE payload for uuid: ${data['uuid']}");

    final deviceUuid = data['uuid'] as String?;
    // if (deviceUuid == null) return;

    final db = await DBService().database;

    final existing = await db.query(
      'devices',
      where: 'uuid = ?',
      whereArgs: [deviceUuid],
    );

    print("Found ${existing.length} existing device(s) with uuid $deviceUuid");

    if (existing.isNotEmpty) {
      // Make row editable
      final deviceMap = Map<String, dynamic>.from(existing.first);

      deviceMap['isOnline'] = 0;
      deviceMap['lastSeen'] = DateTime.now().millisecondsSinceEpoch;

      print("Marking device ${deviceMap['uuid']} as offline in the database.");

      await db.update(
        'devices',
        deviceMap,
        where: 'uuid = ?',
        whereArgs: [deviceUuid],
      );
      NearbyConnections().onStatusChange?.call();
    }
  }
}
