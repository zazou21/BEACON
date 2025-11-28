enum ResourceStatus {
  requested,
  fulfilled,
  posted,
  delivered,
}

enum ResourceType {
  foodWater,
  medical,
  shelter,
}

class Resource {
  final String resourceId;
  final String resourceName;
  final String resourceDescription;
  final DateTime createdAt;
  final ResourceType resourceType;
  final ResourceStatus resourceStatus;
  final String userUuid;

  Resource({
    required this.resourceId,
    required this.resourceName,
    required this.resourceDescription,
    required this.resourceStatus,
    required this.resourceType,
    required this.userUuid,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'resourceId': resourceId,
      'resourceName': resourceName,
      'resourceDescription': resourceDescription,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'resourceType': resourceType.name,     // "foodWater", "medical", ...
      'resourceStatus': resourceStatus.name, // "requested", "fulfilled", ...
      'userUuid': userUuid,
    };
  }

  factory Resource.fromMap(Map<String, dynamic> map) {
    return Resource(
      resourceId: map['resourceId'] as String,
      resourceName: map['resourceName'] as String,
      resourceDescription: map['resourceDescription'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int,
      ),
      resourceType: ResourceType.values.firstWhere(
        (e) => e.name == map['resourceType'],
      ),
      resourceStatus: ResourceStatus.values.firstWhere(
        (e) => e.name == map['resourceStatus'],
      ),
      userUuid: map['userUuid'] as String,
    );
  }
}
