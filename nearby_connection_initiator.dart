part of 'nearby_connections.dart';

class NearbyConnectionsInitiator extends NearbyConnectionsBase {
  final Map<String, PendingConnection> _pendingConnections = {};
  final Map<String, PendingInvite> _pendingInvites = {};
  final List<Device> _availableDevices = [];

  Cluster? _createdCluster;

  // Getters for reactive state
  Cluster? get createdCluster => _createdCluster;
  List<Device> get availableDevices => List.unmodifiable(_availableDevices);

  @override
  Future<void> startCommunication() async {
    if (!await requestNearbyPermissions()) return;

    final db = await DBService().database;
    final existing = await db.query(
      "clusters",
      where: "ownerUuid = ?",
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      print('[Nearby] existing cluster found for initiator');
      _createdCluster = Cluster.fromMap(existing.first);
      notifyListeners();
      return;
    }

    final clusterId = const Uuid().v4();
    final cluster = Cluster(
      clusterId: clusterId,
      ownerUuid: uuid,
      ownerEndpointId: '',
      name: deviceName,
    );
    _createdCluster = cluster;

    try {
      await db.transaction((txn) async {
        await txn.insert(
          'clusters',
          cluster.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.insert('cluster_members', {
          'clusterId': clusterId,
          'deviceUuid': uuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });
      await _startAdvertising(clusterId, cluster.name);
      await _startDiscovery();
      notifyListeners();
    } catch (e) {
      print('[Nearby] DB error while creating cluster: $e');
    }
  }

  Future<void> _startAdvertising(String clusterId, String clusterName) async {
    // Choose a consistent prefix "as" (advertiser server)
    final endpointName = "as|$uuid|$clusterId|$clusterName";
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
      print('[Nearby] startAdvertising error: $e');
    }
  }

  Future<void> _startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        deviceName,
        NearbyConnectionsBase.STRATEGY,
        serviceId: NearbyConnectionsBase.SERVICE_ID,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
    } catch (e) {
      print('[Nearby] startDiscovery error: $e');
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    try {
      final parts = info.endpointName.split('|');
      // Accept either "uuid|clusterId" (short) or "type|uuid|clusterId|name"
      String joinerUuid = '';
      String clusterId = '';

      if (parts.length >= 4) {
        // expected "as|uuid|clusterId|name"
        joinerUuid = parts[1];
        clusterId = parts[2];
      } else if (parts.length >= 2) {
        // either "uuid|clusterId" or something similar
        joinerUuid = parts[0];
        clusterId = parts[1];
      } else {
        return;
      }

      _pendingConnections[endpointId] = PendingConnection(
        joinerUuid,
        clusterId,
      );

      // NOTE: keep acceptConnection param name consistent across your codebase.
      // If plugin expects a different named parameter, replace everywhere with the plugin's exact name.
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: onPayloadReceived,
        onPayloadTransferUpdate: onPayloadUpdate,
      );
    } catch (e) {
      print('[Nearby] _onConnectionInitiated error: $e');
      _pendingConnections.remove(endpointId);
    }
  }

  void _onConnectionResult(String endpointId, Status status) async {
    if (status != Status.CONNECTED) {
      _pendingConnections.remove(endpointId);
      return;
    }

    final data = _pendingConnections.remove(endpointId);
    if (data == null) return;

    final joinerUuid = data.remoteUuid;
    final clusterId = data.clusterId;

    try {
      final db = await DBService().database;
      await db.transaction((txn) async {
        await txn.update(
          "devices",
          {"status": "Connected", "lastSeen": DateTime.now().toIso8601String()},
          where: "uuid = ?",
          whereArgs: [joinerUuid],
        );

        await txn.insert("cluster_members", {
          "clusterId": clusterId,
          "deviceUuid": joinerUuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });

      _activeConnections[endpointId] = joinerUuid;
      if (!_connectedEndpoints.contains(endpointId)) {
        _connectedEndpoints.add(endpointId);
      }

      await _sendClusterInfo(clusterId);
      await _loadAvailableDevices();
      notifyListeners();
    } catch (e) {
      print('[Nearby] _onConnectionResult db error: $e');
    }
  }

  Future<void> _sendClusterInfo(String clusterId) async {
    print("[Nearby] Sending CLUSTER_INFO for clusterId: $clusterId");
    final db = await DBService().database;

    final devicesInCluster = await db.query(
      "devices",
      where:
          "uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)",
      whereArgs: [clusterId],
    );

    final clusterMembers = await db.query(
      "cluster_members",
      where: "clusterId = ?",
      whereArgs: [clusterId],
    );

    final selfDevice = Device(
      uuid: uuid,
      deviceName: deviceName,
      endpointId: '',
      status: "Connected",
      lastSeen: DateTime.now(),
    );

    final devicesList = List<Map<String, dynamic>>.from(devicesInCluster);
    devicesList.add(selfDevice.toMap());

    for (final epId in _connectedEndpoints) {
      final pending = _activeConnections[epId];
      if (pending == null) continue;

      final isMember = await db.query(
        "cluster_members",
        where: "clusterId = ? AND deviceUuid = ?",
        whereArgs: [clusterId, pending],
        limit: 1,
      );

      if (isMember.isEmpty) continue;

      // PASS the payload as a Map (previous version had invalid Dart syntax)
      sendChatMessage(
        epId,
        jsonEncode({
          "type": "CLUSTER_INFO",
          "devices": devicesList,
          "members": clusterMembers,
          "joinerUuid": pending,
        }),
      );
    }
  }

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    final parts = endpointName.split('|');
    if (parts.isEmpty) return;

    // Expect either "as|uuid|clusterId|name" or "ac|uuid|name" etc.
    final type = parts[0];
    if (type != 'as') return;

    if (parts.length < 3) return;
    final devUuid = parts[1];
    final name = parts[2];

    final db = await DBService().database;
    final d = await db.query(
      "devices",
      where: "uuid = ?",
      whereArgs: [devUuid],
      limit: 1,
    );

    if (d.isNotEmpty) {
      await db.update(
        "devices",
        {
          "endpointId": endpointId,
          "inRange": 1,
          "lastSeen": DateTime.now().toIso8601String(),
        },
        where: "uuid = ?",
        whereArgs: [devUuid],
      );
    } else {
      final device = Device(
        uuid: devUuid,
        deviceName: name,
        endpointId: endpointId,
        status: "Available",
        lastSeen: DateTime.now(),
        inRange: true,
      );
      await db.insert(
        "devices",
        device.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await _loadAvailableDevices();
    notifyListeners();
  }

  Future<void> _loadAvailableDevices() async {
    if (_createdCluster == null) return;

    final db = await DBService().database;
    final results = await db.query(
      "devices",
      where: "inRange = ? AND uuid != ?",
      whereArgs: [1, uuid],
    );

    final clusterMembers = await db.query(
      "cluster_members",
      where: "clusterId = ?",
      whereArgs: [_createdCluster!.clusterId],
    );

    _availableDevices.clear();
    _availableDevices.addAll(
      results
          .map((map) => Device.fromMap(map))
          .where((d) => !clusterMembers.any((cm) => cm['deviceUuid'] == d.uuid))
          .toList(),
    );
  }

  void _onEndpointLost(String? endpointId) async {
    final db = await DBService().database;
    final d = await db.query(
      "devices",
      where: "endpointId = ?",
      whereArgs: [endpointId],
      limit: 1,
    );
    if (d.isNotEmpty) {
      await db.update(
        "devices",
        {"inRange": 0, "lastSeen": DateTime.now().toIso8601String()},
        where: "endpointId = ?",
        whereArgs: [endpointId],
      );
      await _loadAvailableDevices();
      notifyListeners();
    }
  }

  void _onDisconnected(String endpointId) async {
    print(endpointId + ' disconnected from initiator side');

    final devUuid = _activeConnections.remove(endpointId);
    _connectedEndpoints.remove(endpointId);
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
        whereArgs: [devUuid],
      );

      await _loadAvailableDevices();
      notifyListeners();
    } catch (e) {
      print('[Nearby] disconnect cleanup error: $e');
    }
  }

  Future<void> inviteToCluster(String endpointId, String clusterId) async {
    final name = "$uuid|$clusterId";
    _pendingInvites[endpointId] = PendingInvite('', clusterId);

    try {
      await Nearby().requestConnection(
        name,
        endpointId,
        onConnectionInitiated: _onInviteConnectionInitiated,
        onConnectionResult: _onInviteConnectionResult,
        onDisconnected: _onInviteDisconnected,
      );
    } catch (e) {
      print('[Nearby] inviteToCluster error: $e');
      _pendingInvites.remove(endpointId);
    }
  }

  void _onInviteConnectionInitiated(
    String endpointId,
    ConnectionInfo info,
  ) async {
    try {
      final parts = info.endpointName.split('|');
      if (parts.isEmpty) return;

      final joinerUuid = parts[1];
      final existing = _pendingInvites[endpointId];
      final clusterId = existing?.clusterId ?? '';

      _pendingInvites[endpointId] = PendingInvite(joinerUuid, clusterId);

      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: onPayloadReceived,
        onPayloadTransferUpdate: onPayloadUpdate,
      );
    } catch (e) {
      print('[Nearby] _onInviteConnectionInitiated error: $e');
      _pendingInvites.remove(endpointId);
    }
  }

  void _onInviteConnectionResult(String endpointId, Status status) async {
    if (status != Status.CONNECTED) {
      _pendingInvites.remove(endpointId);
      return;
    }

    final data = _pendingInvites.remove(endpointId);
    if (data == null) return;

    final joinerUuid = data.joinerUuid;
    final clusterId = data.clusterId;

    try {
      final db = await DBService().database;
      await db.transaction((txn) async {
        await txn.update(
          "devices",
          {"status": "Connected", "lastSeen": DateTime.now().toIso8601String()},
          where: "uuid = ?",
          whereArgs: [joinerUuid],
        );

        await txn.insert("cluster_members", {
          "clusterId": clusterId,
          "deviceUuid": joinerUuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });

      _activeConnections[endpointId] = joinerUuid;
      if (!_connectedEndpoints.contains(endpointId)) {
        _connectedEndpoints.add(endpointId);
      }

      await _sendClusterInfo(clusterId);
      await _loadAvailableDevices();
      notifyListeners();
    } catch (e) {
      print('[Nearby] _onInviteConnectionResult db error: $e');
    }
  }

  void _onInviteDisconnected(String endpointId) async {
    final devUuid = _activeConnections.remove(endpointId);
    _connectedEndpoints.remove(endpointId);
    print(endpointId + ' disconnected from invite side');
    if (devUuid == null) return;
    print('[Nearby] cleaning up after disconnect for $devUuid');

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
        whereArgs: [devUuid],
      );
      await _loadAvailableDevices();
      notifyListeners();
    } catch (e) {
      print('[Nearby] disconnect cleanup error: $e');
    }
  }

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
