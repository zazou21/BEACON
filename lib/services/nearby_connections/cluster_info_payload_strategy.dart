import 'package:nearby_connections/nearby_connections.dart';
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
    final ownerDeviceMap = data['owner_device'] as Map<String, dynamic>?;
    final members = data['members'] as List<dynamic>?;

    if (clusterId == null || ownerDeviceMap == null || members == null) {
      print("Error: Missing required fields in CLUSTER_INFO payload");
      return;
    }

    try {
      final joinerUuid = await _getDeviceUUID();
      final db = await DBService().database;

      // Parse owner device
      final ownerDevice = Device.fromMap(ownerDeviceMap);

      // Save owner device in database
      await db.insert(
        'devices',
        Device(
          uuid: ownerDevice.uuid,
          deviceName: ownerDevice.deviceName,
          endpointId: endpointId,
          status: "Connected",
          lastSeen: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print("Saved cluster owner device to database");

      // Process cluster members and connect to those in range
      int connectedCount = 0;
      for (final m in members) {
        final memberMap = Map<String, dynamic>.from(m);
        final memberDeviceUuid = memberMap['deviceUuid'] as String;

        // Skip joiner's own membership
        if (memberDeviceUuid == joinerUuid) continue;

        // Save cluster membership
        await db.insert('cluster_members', {
          'clusterId': memberMap['clusterId'],
          'deviceUuid': memberDeviceUuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Query database for device with this UUID
        final deviceRows = await db.query(
          'devices',
          where: 'uuid = ? AND inRange = ?',
          whereArgs: [memberDeviceUuid, 1],
          limit: 1,
        );

        if (deviceRows.isEmpty) {
          print(
            "[Nearby] Member $memberDeviceUuid not in range or not discovered yet",
          );
          continue;
        }

        final device = Device.fromMap(deviceRows.first);

        // Verify endpoint ID exists and is not empty
        if (device.endpointId.isEmpty) {
          print(
            "[Nearby] Member ${device.deviceName} has no valid endpoint ID",
          );
          continue;
        }

        // Skip if already connected
        if (beacon.connectedEndpoints.contains(device.endpointId)) {
          print("[Nearby] Already connected to ${device.deviceName}");
          continue;
        }

        // Check if connection is already being established (pending)
        if (beacon.activeConnections.containsKey(device.endpointId)) {
          print(
            "[Nearby] Connection to ${device.deviceName} already in progress",
          );
          connectedCount++; // Count as success since connection is being established
          continue;
        }

        // Attempt to connect to this cluster member
        try {
          await _connectToClusterMember(device, clusterId, joinerUuid);
          connectedCount++;

          // Delay between connections to avoid overwhelming the system
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          // Handle the ALREADY_CONNECTED error gracefully
          if (e.toString().contains('STATUS_ALREADY_CONNECTED_TO_ENDPOINT')) {
            print(
              "[Nearby] Connection to ${device.deviceName} already established from peer side - this is normal",
            );
            connectedCount++; // Count as success since connection exists from other direction
          } else {
            print("[Nearby] Failed to connect to ${device.deviceName}: $e");
            // Continue to next member
          }
        }
      }

      print("Initiated connections to $connectedCount cluster members");

      // Trigger state change notification for UI update
      beacon.notifyListeners();
    } catch (e) {
      print("Error handling CLUSTER_INFO payload: $e");
    }
  }

  Future<void> _connectToClusterMember(
    Device device,
    String clusterId,
    String joinerUuid,
  ) async {
    print(
      "[Nearby] Requesting connection to ${device.deviceName} (${device.endpointId})",
    );

    final connectionName = "$joinerUuid|$clusterId";

    print(
      '[Nearby] Sending connection invite to endpoint id ${device.endpointId}',
    );

    // Add to pending connections before requesting to prevent race condition
    beacon.activeConnections[device.endpointId] = device.uuid;

    try {
      await Nearby().requestConnection(
        connectionName,
        device.endpointId,
        onConnectionInitiated: (id, info) async {
          print("[Nearby] Peer connection initiated with ${device.deviceName}");

          // Add delay to avoid race condition
          await Future.delayed(const Duration(milliseconds: 150));

          try {
            await Nearby().acceptConnection(
              id,
              onPayLoadRecieved: beacon.onPayloadReceived,
              onPayloadTransferUpdate: beacon.onPayloadUpdate,
            );
            print("[Nearby] Connection accepted for ${device.deviceName}");
          } catch (e) {
            print(
              "[Nearby] Error accepting connection to ${device.deviceName}: $e",
            );
          }
        },
        onConnectionResult: (id, status) async {
          if (status == Status.CONNECTED) {
            print(
              "[Nearby] Successfully connected to peer ${device.deviceName}",
            );

            // Update device status in database
            final db = await DBService().database;
            await db.update(
              "devices",
              {
                "status": "Connected",
                "lastSeen": DateTime.now().toIso8601String(),
              },
              where: "uuid = ?",
              whereArgs: [device.uuid],
            );

            // Ensure it's in active connections
            beacon.activeConnections[id] = device.uuid;
            if (!beacon.connectedEndpoints.contains(id)) {
              beacon.connectedEndpoints.add(id);
            }

            beacon.notifyListeners();
          } else {
            print(
              "[Nearby] Failed to connect to peer ${device.deviceName}: $status",
            );
            // Remove from pending on failure
            beacon.activeConnections.remove(id);
          }
        },
        onDisconnected: (id) async {
          print("[Nearby] Peer disconnected: ${device.deviceName}");
          beacon.activeConnections.remove(id);
          beacon.connectedEndpoints.remove(id);

          // Update device status
          final db = await DBService().database;
          await db.update(
            "devices",
            {
              "status": "Disconnected",
              "lastSeen": DateTime.now().toIso8601String(),
            },
            where: "uuid = ?",
            whereArgs: [device.uuid],
          );

          beacon.notifyListeners();
        },
      );
    } catch (e) {
      // Remove from pending connections on error
      beacon.activeConnections.remove(device.endpointId);
      print("[Nearby] Error requesting connection to ${device.deviceName}: $e");
      rethrow;
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
