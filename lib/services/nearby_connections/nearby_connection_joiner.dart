part of 'nearby_connections.dart';


class NearbyConnectionsJoiner extends NearbyConnectionsBase {
  final Map<String, PendingConnection> _pendingConnections = {};
  final List<String> availableClusters = [];

  Cluster? joinedCluster;

  void Function(String endpointId, ConnectionInfo info)? onConnectionRequest;
  void Function(Map<String, String> cluster)? onClusterFound;
  void Function(String clusterId)? onClusterJoinedJoinerSide;

  @override
  Future<void> startCommunication() async {
    if (!await requestNearbyPermissions()) return;

    final db = await DBService().database;
    final existing = await db.query(
      "cluster_members",
      where: "deviceUuid = ?",
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      print('[Nearby] existing cluster membership found for joiner');
      return;
    }

    await _startAdvertising();
    await _startDiscovery();
  }

  Future<void> _startAdvertising() async {
    final endpointName = "as|$uuid|$deviceName";

    try {
      await Nearby().startAdvertising(
        endpointName,
        NearbyConnectionsBase.STRATEGY,
        serviceId: NearbyConnectionsBase.SERVICE_ID,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      print('[Nearby] startAdvertising joiner error: $e');
    }
  }

  Future<void> _startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        deviceName,
        NearbyConnectionsBase.STRATEGY,
        serviceId: NearbyConnectionsBase.SERVICE_ID,
        onEndpointFound: _onClusterFoundHandler,
        onEndpointLost: _onClusterLost,
      );
    } catch (e) {
      print('[Nearby] startDiscovery joiner error: $e');
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    final parts = info.endpointName.split('|');
    if (parts.length < 2) {
      print('[Nearby] joiner: bad endpoint name: ${info.endpointName}');
      return;
    }

    final ownerUuid = parts[0];
    final clusterId = parts[1];

    _pendingConnections[endpointId] = PendingConnection(ownerUuid, clusterId);
    onConnectionRequest?.call(endpointId, info);
  }

  Future<void> acceptInvite(String endpointId) async {
    try {
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: onPayloadReceived,
        onPayloadTransferUpdate: onPayloadUpdate,
      );
    } catch (e) {
      print('[Nearby] acceptInvite error: $e');
    }
  }

  void _onConnectionResult(String endpointId, Status status) async {
    if (status != Status.CONNECTED) {
      _pendingConnections.remove(endpointId);
      return;
    }

    final data = _pendingConnections.remove(endpointId);
    if (data == null) return;

    final ownerUuid = data.remoteUuid;
    final clusterId = data.clusterId;

    try {
      final db = await DBService().database;
      await db.transaction((txn) async {
        await txn.insert(
          "clusters",
          Cluster(
            clusterId: clusterId,
            ownerUuid: ownerUuid,
            name: "Joined Cluster",
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.insert("cluster_members", {
          "clusterId": clusterId,
          "deviceUuid": uuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });

      _activeConnections[endpointId] = ownerUuid;
      if (!connectedEndpoints.contains(endpointId)) {
        connectedEndpoints.add(endpointId);
      }

      onClusterJoinedJoinerSide?.call(clusterId);
    } catch (e) {
      print('[Nearby] _onConnectionResult db error: $e');
    }
  }

  void _onDisconnected(String endpointId) async {
    final devUuid = _activeConnections.remove(endpointId);
    connectedEndpoints.remove(endpointId);
    joinedCluster = null;

    if (devUuid == null) return;

    try {
      final db = await DBService().database;
      await db.update(
        "devices",
        {
          "status": "Disconnected",
          "lastSeen": DateTime.now().toIso8601String(),
        },
        where: "uuid = ?",
        whereArgs: [devUuid],
      );

      await db.delete(
        "cluster_members",
        where: "deviceUuid = ?",
        whereArgs: [uuid],
      );
    } catch (e) {
      print('[Nearby] joiner disconnect cleanup error: $e');
    }
  }

  Future<void> joinCluster(
    String endpointId,
    String clusterId,
    String clusterName,
  ) async {
    final nameToSend = "$uuid|$clusterId";

    try {
      await Nearby().requestConnection(
        nameToSend,
        endpointId,
        onConnectionInitiated: (id, info) async {
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: onPayloadReceived,
            onPayloadTransferUpdate: onPayloadUpdate,
          );
        },
        onConnectionResult: (id, status) async {
          if (status != Status.CONNECTED) return;

          final db = await DBService().database;
          try {
            final cluster = await db.query(
              "clusters",
              where: "clusterId = ?",
              whereArgs: [clusterId],
              limit: 1,
            );

            if (cluster.isNotEmpty) {
              joinedCluster = Cluster.fromMap(cluster.first);
            }

            db.insert("cluster_members", {
              "clusterId": clusterId,
              "deviceUuid": uuid,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          } catch (e) {
            print('[Nearby] joinCluster DB error: $e');
          }

          _activeConnections[id] = joinedCluster!.ownerUuid;
          if (!connectedEndpoints.contains(id)) connectedEndpoints.add(id);

          onClusterJoinedJoinerSide?.call(clusterId);
        },
        onDisconnected: (id) {
          final devUuid = _activeConnections.remove(id);
          connectedEndpoints.remove(id);
          joinedCluster = null;

          DBService().database.then(
            (database) => database.delete(
              "cluster_members",
              where: "deviceUuid = ?",
              whereArgs: [uuid],
            ),
          );
        },
      );
    } catch (e) {
      print("[Nearby] requestConnection error: $e");
    }
  }

  Future<void> disconnectFromCluster() async {
    for (final endpointId in connectedEndpoints) {
      final devUuid = _activeConnections[endpointId];
      if (devUuid == null) continue;
      if (devUuid == joinedCluster!.ownerUuid) {
        await Nearby().disconnectFromEndpoint(endpointId);
      }
    }
  }

  void _onClusterFoundHandler(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    final parts = endpointName.split('|');
    if (parts.length < 2) return;

    final clusterType = parts[0];
    if (clusterType != 'ac') return;

    final ownerUuid = parts[1];
    final clusterId = parts[2];
    final clusterName = parts[3];

    try {
      final db = await DBService().database;
      await db.insert(
        "clusters",
        Cluster(
          clusterId: clusterId,
          ownerUuid: ownerUuid,
          name: clusterName,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print('[Nearby] insert cluster error: $e');
    }

    onClusterFound?.call({
      "endpointId": endpointId,
      "clusterId": clusterId,
      "clusterName": clusterName,
    });
  }

  void _onClusterLost(String? endpointId) {}

  @override
  Future<void> stopAdvertising() async {
    try {
      await Nearby().stopAdvertising();
    } catch (e) {
      print('[Nearby] stopAdvertising error: $e');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    try {
      await Nearby().stopDiscovery();
    } catch (e) {
      print('[Nearby] stopDiscovery error: $e');
    }
  }
}
