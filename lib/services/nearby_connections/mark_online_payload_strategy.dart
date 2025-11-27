import 'payload_strategy.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';
import 'nearby_connections.dart';
import 'payload_strategy.dart';
import 'package:beacon_project/services/db_service.dart';
import 'nearby_connections.dart';

class MarkOnlinePayloadStrategy implements PayloadStrategy {
  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("Handling MARK_ONLINE payload for endpointId: $endpointId");

    final deviceUuid = data['uuid'] as String?;
    // if (deviceUuid == null) return;

    final db = await DBService().database;

    final existing = await db.query(
      'devices',
      where: 'uuid = ?',
      whereArgs: [deviceUuid],
    );

    if (existing.isNotEmpty) {
      // Make mutable
      final deviceMap = Map<String, dynamic>.from(existing.first);

      deviceMap['isOnline'] = 1;
      deviceMap['lastSeen'] = DateTime.now().millisecondsSinceEpoch;

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
