part of 'nearby_connections.dart';

class NearbyConnectionsJoiner extends NearbyConnectionsBase {
  final Map<String, PendingConnection> _pendingConnections = {};
  final List<Map<String, String>> _discoveredClusters = [];

  Cluster? _joinedCluster;
  ConnectionInfo? _pendingInviteInfo;
  String? _pendingInviteEndpointId;

  // Getters for reactive state
  Cluster? get joinedCluster => _joinedCluster;
  List<Map<String, String>> get discoveredClusters =>
      List.unmodifiable(_discoveredClusters);
  ConnectionInfo? get pendingInviteInfo => _pendingInviteInfo;
  String? get pendingInviteEndpointId => _pendingInviteEndpointId;

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
      final clusterId = existing.first['clusterId'] as String;
      final clusterMaps = await db.query(
        "clusters",
        where: "clusterId = ?",
        whereArgs: [clusterId],
      );
      if (clusterMaps.isNotEmpty) {
        _joinedCluster = Cluster.fromMap(clusterMaps.first);
        notifyListeners();
      }
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

    print(
      '[Nearby] joiner: connection initiated from $endpointId '
      'for cluster $clusterId owned by $ownerUuid',
    );

    _pendingConnections[endpointId] = PendingConnection(ownerUuid, clusterId);
    _pendingInviteEndpointId = endpointId;
    _pendingInviteInfo = info;
    notifyListeners();
  }

  Future<void> acceptInvite(String endpointId) async {
    try {
      print('[Nearby] acceptInvite: connection accepted for $endpointId');

      final pending = _pendingConnections.remove(endpointId);
      if (pending == null) {
        print('[Nearby] acceptInvite: no pending connection data');
        return;
      }

      final ownerUuid = pending.remoteUuid;
      final clusterId = pending.clusterId;

      final db = await DBService().database;

      await db.insert("cluster_members", {
        "clusterId": clusterId,
        "deviceUuid": uuid,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      final clusterRow = await db.query(
        "clusters",
        where: "clusterId = ?",
        whereArgs: [clusterId],
        limit: 1,
      );

      if (clusterRow.isNotEmpty) {
        _joinedCluster = Cluster.fromMap(clusterRow.first);
      }

      _activeConnections[endpointId] = ownerUuid;
      if (!_connectedEndpoints.contains(endpointId)) {
        _connectedEndpoints.add(endpointId);
      }

      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: onPayloadReceived,
        onPayloadTransferUpdate: onPayloadUpdate,
      );

      _pendingInviteInfo = null;
      _pendingInviteEndpointId = null;

      await _loadDiscoveredClusters();
      notifyListeners();

      print('[Nearby] acceptInvite: cluster joined successfully');
    } catch (e) {
      print('[Nearby] acceptInvite error: $e');
    }
  }

  void rejectInvite() {
    _pendingInviteInfo = null;
    _pendingInviteEndpointId = null;
    notifyListeners();
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

      await db.insert("cluster_members", {
        "clusterId": clusterId,
        "deviceUuid": uuid,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      _activeConnections[endpointId] = ownerUuid;
      if (!_connectedEndpoints.contains(endpointId)) {
        _connectedEndpoints.add(endpointId);
      }

      notifyListeners();
    } catch (e) {
      print('[Nearby] _onConnectionResult db error: $e');
    }
  }

  void _onDisconnected(String endpointId) async {
    final devUuid = _activeConnections.remove(endpointId);
    _connectedEndpoints.remove(endpointId);
    _joinedCluster = null;

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

      await _loadDiscoveredClusters();
      notifyListeners();
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
              print('[Nearby] joinCluster: cluster found in DB');
              _joinedCluster = Cluster.fromMap(cluster.first);
            }

            db.insert("cluster_members", {
              "clusterId": clusterId,
              "deviceUuid": uuid,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          } catch (e) {
            print('[Nearby] joinCluster DB error: $e');
          }

          _activeConnections[id] = _joinedCluster!.ownerUuid;
          if (!_connectedEndpoints.contains(id)) _connectedEndpoints.add(id);

          await _loadDiscoveredClusters();
          notifyListeners();
        },
        onDisconnected: (id) async {
          final devUuid = _activeConnections.remove(id);
          _connectedEndpoints.remove(id);
          _joinedCluster = null;

          final db = await DBService().database;
          await db.delete(
            "cluster_members",
            where: "deviceUuid = ?",
            whereArgs: [uuid],
          );

          await _loadDiscoveredClusters();
          notifyListeners();
        },
      );
    } catch (e) {
      print("[Nearby] requestConnection error: $e");
    }
  }

  Future<void> disconnectFromCluster() async {
    print('[Nearby] disconnectFromCluster called');
    if (_joinedCluster == null) {
      print('[Nearby] No joined cluster to disconnect from');
      return;
    }

    final clusterId = _joinedCluster!.clusterId;
    final ownerUuid = _joinedCluster!.ownerUuid;

    print('[Nearby] Disconnecting from cluster $clusterId owned by $ownerUuid');

    for (final endpointId in _connectedEndpoints) {
      final devUuid = _activeConnections[endpointId];
      if (devUuid == ownerUuid) {
        await Nearby().disconnectFromEndpoint(endpointId);
      }
    }

    _connectedEndpoints.clear();
    _activeConnections.clear();

    final db = await DBService().database;
    try {
      await db.delete(
        "cluster_members",
        where: "deviceUuid = ?",
        whereArgs: [uuid],
      );
    } catch (e) {
      print('[Nearby] disconnectFromCluster DB error: $e');
    }

    _joinedCluster = null;

    try {
      await db.update(
        "devices",
        {
          "status": "Disconnected",
          "lastSeen": DateTime.now().toIso8601String(),
        },
        where: "uuid = ?",
        whereArgs: [ownerUuid],
      );
    } catch (e) {
      print('[Nearby] disconnectFromCluster cleanup error: $e');
    }

    await _loadDiscoveredClusters();
    notifyListeners();
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
          ownerEndpointId: endpointId,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await _loadDiscoveredClusters();
      notifyListeners();
    } catch (e) {
      print('[Nearby] insert cluster error: $e');
    }
  }

  Future<void> _loadDiscoveredClusters() async {
    final db = await DBService().database;
    final clusters = await db.query("clusters");
    final clusterMembers = await db.query("cluster_members");

    final sp = await SharedPreferences.getInstance();
    final myUuid = sp.getString('device_uuid');

    _discoveredClusters.clear();

    for (var clusterMap in clusters) {
      final clusterId = clusterMap['clusterId'] as String;

      final isMember = clusterMembers.any(
        (cm) => cm['clusterId'] == clusterId && cm['deviceUuid'] == myUuid,
      );
      if (isMember) continue;

      _discoveredClusters.add({
        "clusterId": clusterId,
        "clusterName": clusterMap['name'] as String,
        "endpointId": clusterMap['ownerEndpointId'] as String,
      });
    }
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
