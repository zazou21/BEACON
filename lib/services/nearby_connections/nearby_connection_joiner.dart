part of 'nearby_connections.dart';

class NearbyConnectionsJoiner extends NearbyConnectionsBase {
  static final NearbyConnectionsJoiner _instance =
      NearbyConnectionsJoiner._internal();

  factory NearbyConnectionsJoiner() {
    return _instance;
  }
  NearbyConnectionsJoiner._internal();
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
    print("[Nearby]: starting joiner");

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
    print("[Nearby]: joiner advertising");
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
    print("[Nearby]: joiner discovering");
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

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    print('[Nearby] joiner: connection initiated from $endpointId');

    // Add to pending immediately to prevent duplicate attempts
    final parts = info.endpointName.split('|');
    if (parts.length >= 2) {
      final initiatorUuid = parts[0];
      final clusterId = parts[1];

      _pendingConnections[endpointId] = PendingConnection(
        initiatorUuid,
        clusterId,
      );

      // Check membership and auto-accept if already in cluster
      await _determineConnectionType(
        endpointId,
        info,
        initiatorUuid,
        clusterId,
      );
    }
  }

  Future<void> _determineConnectionType(
    String endpointId,
    ConnectionInfo info,
    String initiatorUuid,
    String clusterId,
  ) async {
    try {
      final db = await DBService().database;

      // Check if we're already a member of this cluster
      final existingMembership = await db.query(
        "cluster_members",
        where: "clusterId = ? AND deviceUuid = ?",
        whereArgs: [clusterId, uuid],
        limit: 1,
      );

      final isMember = existingMembership.isNotEmpty;

      if (isMember) {
        // Scenario 2: We're already in the cluster, this is a peer mesh connection
        // Auto-accept without prompting user
        print(
          '[Nearby] Auto-accepting peer mesh connection from $initiatorUuid',
        );

        _pendingConnections[endpointId] = PendingConnection(
          initiatorUuid,
          clusterId,
        );

        await Nearby().acceptConnection(
          endpointId,
          onPayLoadRecieved: onPayloadReceived,
          onPayloadTransferUpdate: onPayloadUpdate,
        );

        // Update the device status in database
        await db.update(
          "devices",
          {"status": "Connected", "lastSeen": DateTime.now().toIso8601String()},
          where: "uuid = ?",
          whereArgs: [initiatorUuid],
        );
      } else {
        // Scenario 1: This is a cluster owner invite - prompt user to accept/reject
        print('[Nearby] Cluster invite received from owner $initiatorUuid');

        _pendingConnections[endpointId] = PendingConnection(
          initiatorUuid,
          clusterId,
        );
        _pendingInviteEndpointId = endpointId;
        _pendingInviteInfo = info;
        notifyListeners(); // Trigger UI to show accept/reject dialog
      }
    } catch (e) {
      print('[Nearby] _determineConnectionType error: $e');
    }
  }

  void _onConnectionResult(String endpointId, Status status) async {
    print(
      '[Nearby] joiner: connection result from $endpointId - status: $status',
    );

    if (status != Status.CONNECTED) {
      _pendingConnections.remove(endpointId);
      return;
    }

    final data = _pendingConnections.remove(endpointId);
    if (data == null) return;

    final remoteUuid = data.remoteUuid;
    final clusterId = data.clusterId;

    try {
      final db = await DBService().database;

      // Check if we're already a member (peer mesh scenario)
      final existingMembership = await db.query(
        "cluster_members",
        where: "clusterId = ? AND deviceUuid = ?",
        whereArgs: [clusterId, uuid],
        limit: 1,
      );

      if (existingMembership.isEmpty) {
        // First time joining - add membership
        await db.insert("cluster_members", {
          "clusterId": clusterId,
          "deviceUuid": uuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Load cluster info
        final clusterRow = await db.query(
          "clusters",
          where: "clusterId = ?",
          whereArgs: [clusterId],
          limit: 1,
        );

        if (clusterRow.isNotEmpty) {
          _joinedCluster = Cluster.fromMap(clusterRow.first);
        }
      }

      // Add to active connections (for both scenarios)
      _activeConnections[endpointId] = remoteUuid;
      if (!_connectedEndpoints.contains(endpointId)) {
        _connectedEndpoints.add(endpointId);
      }

      // Update device status
      await db.update(
        "devices",
        {"status": "Connected", "lastSeen": DateTime.now().toIso8601String()},
        where: "uuid = ?",
        whereArgs: [remoteUuid],
      );

      notifyListeners();
      print('[Nearby] Connection established successfully with $remoteUuid');
    } catch (e) {
      print('[Nearby] _onConnectionResult db error: $e');
    }
  }

  Future<void> acceptInvite(String endpointId) async {
    print('[Nearby] acceptInvite called');
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
    print('[Nearby] rejectInvite called');
    _pendingInviteInfo = null;
    _pendingInviteEndpointId = null;
    notifyListeners();
  }

  void _onDisconnected(String endpointId) async {
    print('[Nearby] joiner: disconnected from $endpointId');
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
    print('[Nearby] joinCluster called');

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
    print('[Nearby] endpoint found: $endpointName');
    final parts = endpointName.split('|');
    if (parts.length < 2) return;

    final endpointType = parts[0];

    // Handle device advertising (as)
    if (endpointType == 'as') {
      if (parts.length < 3) return;

      final deviceUuid = parts[1];
      final deviceName = parts[2];

      try {
        final db = await DBService().database;

        // Check if device exists
        final existing = await db.query(
          "devices",
          where: "uuid = ?",
          whereArgs: [deviceUuid],
          limit: 1,
        );

        if (existing.isEmpty) {
          // Device not found - insert new device
          await db.insert(
            "devices",
            Device(
              uuid: deviceUuid,
              deviceName: deviceName,
              endpointId: endpointId,
              status: "Available",
              isOnline: true,
              inRange: true,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          print('[Nearby] New device added: $deviceName ($deviceUuid)');
        } else {
          // Device exists - update endpoint ID and status
          await db.update(
            "devices",
            {
              "endpointId": endpointId,
              "status": "Available",
              "isOnline": 1,
              "inRange": 1,
              "lastSeen": DateTime.now().toIso8601String(),
              "updatedAt": DateTime.now().toIso8601String(),
            },
            where: "uuid = ?",
            whereArgs: [deviceUuid],
          );
          print('[Nearby] Device endpoint updated: $deviceName ($deviceUuid)');
        }

        notifyListeners();
      } catch (e) {
        print('[Nearby] handle device discovery error: $e');
      }
      return;
    }

    // Handle cluster advertising (ac)
    if (endpointType == 'ac') {
      if (parts.length < 4) return;

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
  }

  Future<void> _loadDiscoveredClusters() async {
    print('[Nearby] loading discovered clusters');
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

  void _onClusterLost(String? endpointId) async {
    if (endpointId == null) return;

    print('[Nearby] cluster lost: $endpointId');

    try {
      final db = await DBService().database;

      // Remove the cluster from discovered clusters list
      await db.delete(
        "clusters",
        where: "ownerEndpointId = ?",
        whereArgs: [endpointId],
      );

      // Reload the discovered clusters to update UI
      await _loadDiscoveredClusters();
      notifyListeners();

      print('[Nearby] cluster removed from discovered list');
    } catch (e) {
      print('[Nearby] _onClusterLost cleanup error: $e');
    }
  }

  @override
  Future<void> stopAdvertising() async {
    print('[Nearby]: stopping advertising');
    try {
      await Nearby().stopAdvertising();
    } catch (e) {
      print('[Nearby] stopAdvertising error: $e');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    try {
      print('[Nearby]: stopping discovery');
      await Nearby().stopDiscovery();
    } catch (e) {
      print('[Nearby] stopDiscovery error: $e');
    }
  }

  @override
  Future<void> stopAll() async {
    print("[Nearby]: stopping all for joiner");

    await stopAdvertising();
    await stopDiscovery();

    for (var endpointId in _connectedEndpoints) {
      await Nearby().disconnectFromEndpoint(endpointId);
    }
    _connectedEndpoints.clear();
    _activeConnections.clear();
    _joinedCluster = null;
    _pendingConnections.clear();
    _discoveredClusters.clear();

    notifyListeners();
  }
}
