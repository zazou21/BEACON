import 'package:beacon_project/models/cluster_member.dart';

abstract class ClusterMemberRepository {
  Future<List<ClusterMember>> getMembersByClusterId(String clusterId);
  Future<List<ClusterMember>> getMembersByDeviceUuid(String deviceUuid);
  Future<ClusterMember?> getMember(String clusterId, String deviceUuid);
  Future<void> insertMember(ClusterMember member);
  Future<void> deleteMember(String clusterId, String deviceUuid);
  Future<void> deleteAllMembersByDevice(String deviceUuid);
  Future<void> deleteAllMembersByCluster(String clusterId);
  Future<bool> isMemberOfCluster(String clusterId, String deviceUuid);
}
