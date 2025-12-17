import 'payload_strategy.dart';
import 'nearby_connections.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'package:beacon_project/models/cluster.dart';

class OwnerChangedPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  final DeviceRepository deviceRepository;
  final ClusterRepository clusterRepository;
  final ClusterMemberRepository clusterMemberRepository;

  OwnerChangedPayloadStrategy(
    this.beacon,
    this.deviceRepository,
    this.clusterRepository,
    this.clusterMemberRepository,
  );

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print('[Payload] Handling OWNER_CHANGED');

    final clusterId = data['clusterId'] as String;
    final newOwnerUuid = data['newOwnerUuid'] as String;
    final oldOwnerUuid = data['oldOwnerUuid'] as String;

    try {
      // Get existing cluster
      final cluster = await clusterRepository.getClusterById(clusterId);

      if (cluster != null) {
        // Update cluster ownership
        final updatedCluster = Cluster(
          clusterId: cluster.clusterId,
          ownerUuid: newOwnerUuid,
          ownerEndpointId: cluster.ownerEndpointId,
          name: cluster.name,
          createdAt: cluster.createdAt,
        );
        await clusterRepository.updateCluster(updatedCluster);
      }

      // Remove old owner from cluster members
      await clusterMemberRepository.deleteMember(clusterId, oldOwnerUuid);

      // Mark old owner as disconnected
      await deviceRepository.updateDeviceStatus(oldOwnerUuid, "Disconnected");

      beacon.notifyListeners();

      print('[Payload] Owner changed processed - new owner: $newOwnerUuid');
    } catch (e) {
      print('[Payload] Error handling owner change: $e');
    }
  }
}
