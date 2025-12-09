import 'payload_strategy.dart';
import 'nearby_connections.dart';
import 'package:beacon_project/services/db_service.dart';

class OwnerChangedPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;

  OwnerChangedPayloadStrategy(this.beacon);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print('[Payload] Handling OWNER_CHANGED');

    final clusterId = data['clusterId'] as String;
    final newOwnerUuid = data['newOwnerUuid'] as String;
    final oldOwnerUuid = data['oldOwnerUuid'] as String;

    final db = await DBService().database;

    await db.transaction((txn) async {
      // Update cluster ownership
      await txn.update(
        "clusters",
        {"ownerUuid": newOwnerUuid},
        where: "clusterId = ?",
        whereArgs: [clusterId],
      );

      // Remove old owner from cluster members
      await txn.delete(
        "cluster_members",
        where: "clusterId = ? AND deviceUuid = ?",
        whereArgs: [clusterId, oldOwnerUuid],
      );

      // Mark old owner as disconnected
      await txn.update(
        "devices",
        {
          "status": "Disconnected",
          "lastSeen": DateTime.now().toIso8601String(),
        },
        where: "uuid = ?",
        whereArgs: [oldOwnerUuid],
      );
    });

    beacon.notifyListeners();
    
    print('[Payload] Owner changed processed - new owner: $newOwnerUuid');
  }
}
