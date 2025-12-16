import 'package:sqflite/sqflite.dart';
import 'payload_strategy.dart';
import 'nearby_connections.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/dashboard_mode.dart';
import 'package:nearby_connections/nearby_connections.dart' as nc;
import 'package:shared_preferences/shared_preferences.dart';
import 'mode_change_notifier.dart';

class TransferOwnershipPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;

  TransferOwnershipPayloadStrategy(this.beacon);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print('[Payload] Handling TRANSFER_OWNERSHIP');

    final clusterId = data['clusterId'] as String;
    final clusterName = data['clusterName'] as String;
    final newOwnerUuid = data['newOwnerUuid'] as String;
    final oldOwnerUuid = data['oldOwnerUuid'] as String;
    final members = data['members'] as List<dynamic>;
    final devices = data['devices'] as List<dynamic>;

    // Only proceed if I'm the new owner
    if (newOwnerUuid != beacon.uuid) {
      print('[Payload]: Not selected as new owner');
      return;
    }

    print('[Payload]:I am the new cluster owner!');

    final db = await DBService().database;

    await db.transaction((txn) async {
      // Update cluster ownership
      await txn.update(
        "clusters",
        {
          "ownerUuid": newOwnerUuid,
          "ownerEndpointId": "",
        },
        where: "clusterId = ?",
        whereArgs: [clusterId],
      );

      // Update devices
      for (var deviceMap in devices) {
        final device = deviceMap as Map<String, dynamic>;
        await txn.insert(
          "devices",
          device,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Update cluster members
      for (var memberMap in members) {
        final member = memberMap as Map<String, dynamic>;
        await txn.insert(
          "cluster_members",
          member,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

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

    // Save the new mode to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_mode', 'initiator');

    // Notify all other members about the ownership change
    for (final epId in beacon.connectedEndpoints) {
      if (epId != endpointId) {
        beacon.sendMessage(epId, "OWNER_CHANGED", {
          "clusterId": clusterId,
          "newOwnerUuid": newOwnerUuid,
          "oldOwnerUuid": oldOwnerUuid,
        });
      }
    }

    // Send confirmation to old owner (if still connected)
    beacon.sendMessage(endpointId, "OWNERSHIP_TRANSFERRED", {
      "clusterId": clusterId,
      "newOwnerUuid": newOwnerUuid,
    });

    beacon.notifyListeners();

    // Trigger mode change to rebuild the UI
    ModeChangeNotifier().notifyModeChange(DashboardMode.initiator);

    print('[Payload] Ownership transfer completed');
  }
}
