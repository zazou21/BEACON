
import 'package:beacon_project/models/cluster.dart';

abstract class ClusterRepository {
  Future<Cluster?> getClusterById(String clusterId);
  Future<List<Cluster>> getAllClusters();
  Future<Cluster?> getClusterByOwnerUuid(String ownerUuid);
  Future<void> insertCluster(Cluster cluster);
  Future<void> updateCluster(Cluster cluster);
  Future<void> deleteCluster(String clusterId);
  Future<void> deleteClusterByOwner(String ownerUuid);
}
