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
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt']),
    );
  }
}
