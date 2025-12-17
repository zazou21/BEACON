// lib/models/cluster_member.dart
class ClusterMember {
  String clusterId;
  String deviceUuid;
  DateTime joinedAt;

  ClusterMember({
    required this.clusterId,
    required this.deviceUuid,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'clusterId': clusterId,
      'deviceUuid': deviceUuid,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }

  factory ClusterMember.fromMap(Map<String, dynamic> map) {
    return ClusterMember(
      clusterId: map['clusterId'],
      deviceUuid: map['deviceUuid'],
      // Handle null joinedAt - use current time if null
      joinedAt: map['joinedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int)
          : null, // Will default to DateTime.now() in constructor
    );
  }
}
