// lib/repositories/mock/mock_cluster_repository.dart

import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/models/cluster.dart';

class MockClusterRepository implements ClusterRepository {
  final Map<String, Cluster> _clusters = {};

  @override
  Future<Cluster?> getClusterById(String clusterId) async {
    return _clusters[clusterId];
  }

  @override
  Future<List<Cluster>> getAllClusters() async {
    return _clusters.values.toList();
  }

  @override
  Future<Cluster?> getClusterByOwnerUuid(String ownerUuid) async {
    try {
      return _clusters.values.firstWhere(
        (c) => c.ownerUuid == ownerUuid,
      );
    } catch (e) {
      // Return null if not found instead of casting null to Cluster
      return null;
    }
  }

  @override
  Future<void> insertCluster(Cluster cluster) async {
    _clusters[cluster.clusterId] = cluster;
  }

  @override
  Future<void> updateCluster(Cluster cluster) async {
    _clusters[cluster.clusterId] = cluster;
  }

  @override
  Future<void> deleteCluster(String clusterId) async {
    _clusters.remove(clusterId);
  }

  @override
  Future<void> deleteClusterByOwner(String ownerUuid) async {
    _clusters.removeWhere((key, cluster) => cluster.ownerUuid == ownerUuid);
  }

  // Helper method for testing
  void clear() {
    _clusters.clear();
  }
}
