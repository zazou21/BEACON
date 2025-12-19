import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster_member.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'payload_strategy.dart';
import 'nearby_connections.dart';

class ClusterInfoPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  final DeviceRepository deviceRepository;
  final ClusterMemberRepository clusterMemberRepository;

  ClusterInfoPayloadStrategy(
    this.beacon,
    this.deviceRepository,
    this.clusterMemberRepository,
  );

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("Handling CLUSTER_INFO payload for endpointId: $endpointId");

    final clusterId = data['clusterId'] as String?;
    final ownerDeviceMap = data['owner_device'] as Map<String, dynamic>?;
    final members = data['members'] as List?;

    if (clusterId == null || ownerDeviceMap == null || members == null) {
      print("Error: Missing required fields in CLUSTER_INFO payload");
      return;
    }

    try {
      final joinerUuid = await _getDeviceUUID();

      // Parse owner device
      final ownerDevice = Device.fromMap(ownerDeviceMap);

      // Save owner device using repository
      await deviceRepository.insertDevice(
        Device(
          uuid: ownerDevice.uuid,
          deviceName: ownerDevice.deviceName,
          endpointId: endpointId,
          status: "Connected",
          lastSeen: DateTime.now(),
        ),
      );

      print("Saved cluster owner device to database");

      // Process cluster members and connect to those in range
      int connectedCount = 0;

      for (final m in members) {
        final memberMap = Map<String, dynamic>.from(m);
        final memberDeviceUuid = memberMap['deviceUuid'] as String;

        // Skip joiner's own membership
        if (memberDeviceUuid == joinerUuid) continue;

        // Save cluster membership using repository
        await clusterMemberRepository.insertMember(
          ClusterMember(
            clusterId: memberMap['clusterId'] as String,
            deviceUuid: memberDeviceUuid,
          ),
        );

        // Query for device with this UUID that's in range
        final device = await deviceRepository.getDeviceByUuid(memberDeviceUuid);

        if (device == null || !device.inRange) {
          print(
            "[Nearby] Member $memberDeviceUuid not in range or not discovered yet",
          );
          continue;
        }

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
          connectedCount++;
          continue;
        }

        // Attempt to connect to this cluster member
        try {
          await _connectToClusterMember(device, clusterId, joinerUuid);
          connectedCount++;
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          if (e.toString().contains('STATUS_ALREADY_CONNECTED_TO_ENDPOINT')) {
            print(
              "[Nearby] Connection to ${device.deviceName} already established from peer side - this is normal",
            );
            connectedCount++;
          } else {
            print("[Nearby] Failed to connect to ${device.deviceName}: $e");
          }
        }
      }

      print("Initiated connections to $connectedCount cluster members");
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

            // Update device status using repository
            await deviceRepository.updateDeviceStatus(device.uuid, "Connected");

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
            beacon.activeConnections.remove(id);
          }
        },
        onDisconnected: (id) async {
          print("[Nearby] Peer disconnected: ${device.deviceName}");
          beacon.activeConnections.remove(id);
          beacon.connectedEndpoints.remove(id);

          // Update device status using repository
          await deviceRepository.updateDeviceStatus(
            device.uuid,
            "Disconnected",
          );
          beacon.notifyListeners();
        },
      );
    } catch (e) {
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
