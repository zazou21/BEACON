class Cluster {
  String clusterId;
  String ownerUuid;
  String ownerEndpointId;
  String name;
  DateTime createdAt;
  DateTime updatedAt;

  Cluster({
    required this.clusterId,
    required this.ownerUuid,
    required this.ownerEndpointId,
    required this.name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'clusterId': clusterId,
      'ownerUuid': ownerUuid,
      'ownerEndpointId': ownerEndpointId,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Cluster.fromMap(Map<String, dynamic> map) {
    return Cluster(
      clusterId: map['clusterId'],
      ownerUuid: map['ownerUuid'],
      ownerEndpointId: map['ownerEndpointId'],
      name: map['name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
    );
  }
}
