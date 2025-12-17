// lib/repositories/mock/mock_cluster_member_repository.dart
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'package:beacon_project/models/cluster_member.dart';

class MockClusterMemberRepository implements ClusterMemberRepository {
  final List<ClusterMember> _members = [];

  @override
  Future<List<ClusterMember>> getMembersByClusterId(String clusterId) async {
    return _members.where((m) => m.clusterId == clusterId).toList();
  }

  @override
  Future<List<ClusterMember>> getMembersByDeviceUuid(String deviceUuid) async {
    return _members.where((m) => m.deviceUuid == deviceUuid).toList();
  }

  @override
  Future<ClusterMember?> getMember(String clusterId, String deviceUuid) async {
    try {
      return _members.firstWhere(
        (m) => m.clusterId == clusterId && m.deviceUuid == deviceUuid,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> insertMember(ClusterMember member) async {
    final existing = await getMember(member.clusterId, member.deviceUuid);
    if (existing == null) {
      _members.add(member);
    }
  }

  @override
  Future<void> deleteMember(String clusterId, String deviceUuid) async {
    _members.removeWhere(
      (m) => m.clusterId == clusterId && m.deviceUuid == deviceUuid,
    );
  }

  @override
  Future<void> deleteAllMembersByDevice(String deviceUuid) async {
    _members.removeWhere((m) => m.deviceUuid == deviceUuid);
  }

  @override
  Future<void> deleteAllMembersByCluster(String clusterId) async {
    _members.removeWhere((m) => m.clusterId == clusterId);
  }

  @override
  Future<bool> isMemberOfCluster(String clusterId, String deviceUuid) async {
    return _members.any(
      (m) => m.clusterId == clusterId && m.deviceUuid == deviceUuid,
    );
  }

  // Helper method for testing
  void clear() {
    _members.clear();
  }
}
