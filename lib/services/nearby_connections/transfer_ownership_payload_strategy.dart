import 'payload_strategy.dart';
import 'nearby_connections.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster_member.dart';
import 'package:beacon_project/models/dashboard_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mode_change_notifier.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';

class TransferOwnershipPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  final DeviceRepository deviceRepository;
  final ClusterRepository clusterRepository;
  final ClusterMemberRepository clusterMemberRepository;

  TransferOwnershipPayloadStrategy(
    this.beacon,
    this.deviceRepository,
    this.clusterRepository,
    this.clusterMemberRepository,
  );

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print('[Payload] Handling TRANSFER_OWNERSHIP');

    final clusterId = data['clusterId'] as String;
    final clusterName = data['clusterName'] as String;
    final newOwnerUuid = data['newOwnerUuid'] as String;
    final oldOwnerUuid = data['oldOwnerUuid'] as String;
    final members = data['members'] as List;
    final devices = data['devices'] as List;

    // Only proceed if I'm the new owner
    if (newOwnerUuid != beacon.uuid) {
      print('[Payload]: Not selected as new owner');
      return;
    }

    print('[Payload]: I am the new cluster owner!');

    try {
      // Get existing cluster
      final cluster = await clusterRepository.getClusterById(clusterId);
      
      if (cluster != null) {
        // Update cluster ownership
        final updatedCluster = Cluster(
          clusterId: cluster.clusterId,
          ownerUuid: newOwnerUuid,
          ownerEndpointId: "",
          name: cluster.name,
          createdAt: cluster.createdAt,
        );
        await clusterRepository.updateCluster(updatedCluster);
      }

      // Insert/update devices
      for (var deviceMap in devices) {
        final deviceData = deviceMap as Map<String, dynamic>;
        final device = Device.fromMap(deviceData);
        await deviceRepository.insertDevice(device);
      }

      // Insert/update cluster members
      for (var memberMap in members) {
        final memberData = memberMap as Map<String, dynamic>;
        final member = ClusterMember.fromMap(memberData);
        await clusterMemberRepository.insertMember(member);
      }

      // Remove old owner from cluster members
      await clusterMemberRepository.deleteMember(clusterId, oldOwnerUuid);

      // Mark old owner as disconnected
      await deviceRepository.updateDeviceStatus(oldOwnerUuid, "Disconnected");

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
    } catch (e) {
      print('[Payload] Error during ownership transfer: $e');
    }
  }
}
