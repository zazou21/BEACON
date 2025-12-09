part of 'nearby_connections.dart';

class NearbyConnectionsInitiator extends NearbyConnectionsBase {
  static final NearbyConnectionsInitiator _instance =
      NearbyConnectionsInitiator._internal();

  factory NearbyConnectionsInitiator() {
    return _instance;
  }
  NearbyConnectionsInitiator._internal();

  final Map<String, PendingConnection> _pendingConnections = {};
  final Map<String, PendingInvite> _pendingInvites = {};
  final List<Device> _availableDevices = [];

  Cluster? _createdCluster;

  // Getters for reactive state
  Cluster? get createdCluster => _createdCluster;
  List<Device> get availableDevices => (_availableDevices);

  @override
  @override
  Future<void> startCommunication() async {
    print("[Nearby]: starting initiator");

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

      // IMPORTANT: Always start advertising even if cluster exists
      // This handles the case when transitioning from joiner to initiator
      print('[Nearby] Starting advertising for existing cluster');
      await _startAdvertising(
        _createdCluster!.clusterId,
        _createdCluster!.name,
      );
      await _startDiscovery();

      notifyListeners();
      return;
    }

    // Create new cluster if none exists
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
    print("[Nearby]: initiator advertising");
    final endpointName = "ac|$uuid|$clusterId|$clusterName";
    print("[Nearby]: 📡 Advertising with name: $endpointName");

    try {
      await Nearby().startAdvertising(
        endpointName,
        NearbyConnectionsBase.STRATEGY,
        serviceId: NearbyConnectionsBase.SERVICE_ID,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      print("[Nearby]: ✅ Advertising started successfully as initiator");
    } catch (e) {
      print('[Nearby] ❌ startAdvertising error: $e');
    }
  }

  Future<void> _startDiscovery() async {
    print("[Nearby]: initiator discovering");
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
    print('[Nearby] connection initiated from $endpointId');
    try {
      final parts = info.endpointName.split('|');
      if (parts.length < 2) return;

      final joinerUuid = parts[0];
      final clusterId = parts[1];

      _pendingConnections[endpointId] = PendingConnection(
        joinerUuid,
        clusterId,
      );

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
    print("[Nearby] connection result from $endpointId");

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

      sendMessage(epId, "CLUSTER_INFO", {
        "clusterId": clusterId,
        "senderUuid": uuid,
        "owner_device": selfDevice.toMap(),
        "members": clusterMembers,
      });
    }
  }

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    print('[Nearby] endpoint found: $endpointName');

    final parts = endpointName.split('|');
    if (parts.length < 3) return;

    final type = parts[0];
    if (type != 'as') return;

    final devUuid = parts[1];
    final name = parts[2];

    final db = await DBService().database;
    final d = await db.query(
      "devices",
      where: "uuid = ?",
      whereArgs: [devUuid],
      limit: 1,
    );

    // if device exists, update the endpointId and inRange
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
    }
    // else create a new device
    else {
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
    print('[Nearby] endpoint lost: $endpointId');
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
    print('[Nearby] disconnected from $endpointId');

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
    print('[Nearby] inviting $endpointId to cluster');
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
    print('[Nearby] invite connection initiated from $endpointId');
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
    print('[Nearby] invite connection result from $endpointId');

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
    print('[Nearby] invite disconnected from $endpointId');
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

  Future<void> transferOwnershipBeforeDisconnect() async {
    if (_createdCluster == null || _connectedEndpoints.isEmpty) return;

    print('[Nearby] Transferring cluster ownership before disconnect');

    // Select a random connected device to become new owner
    final newOwnerEndpointId = _connectedEndpoints.first;
    final newOwnerUuid = _activeConnections[newOwnerEndpointId];

    if (newOwnerUuid == null) return;

    final db = await DBService().database;

    // Get all cluster members
    final members = await db.query(
      "cluster_members",
      where: "clusterId = ?",
      whereArgs: [_createdCluster!.clusterId],
    );

    // Get all devices in cluster
    final devices = await db.query(
      "devices",
      where:
          "uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)",
      whereArgs: [_createdCluster!.clusterId],
    );

    // Send ownership transfer message to new owner
    sendMessage(newOwnerEndpointId, "TRANSFER_OWNERSHIP", {
      "clusterId": _createdCluster!.clusterId,
      "clusterName": _createdCluster!.name,
      "newOwnerUuid": newOwnerUuid,
      "oldOwnerUuid": uuid,
      "members": members,
      "devices": devices,
    });

    for (final epId in _connectedEndpoints) {
      if (epId != newOwnerEndpointId) {
        sendMessage(epId, "OWNER_CHANGED", {
          "clusterId": _createdCluster!.clusterId,
          "newOwnerUuid": newOwnerUuid,
          "oldOwnerUuid": uuid,
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
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
    print('[Nearby]: stopping discovery');
    try {
      await Nearby().stopDiscovery();
    } catch (e) {
      print('[Nearby] stopDiscovery error: $e');
    }
  }

  @override
  Future<void> stopAll() async {
    print("[Nearby]: stopping all for initiator");

    // Transfer ownership before stopping
    await transferOwnershipBeforeDisconnect();

    await stopAdvertising();
    await stopDiscovery();

    for (var endpointId in _connectedEndpoints) {
      await Nearby().disconnectFromEndpoint(endpointId);
    }

    //remove self from cluster members
    final db = await DBService().database;
    await db.delete(
      "cluster_members",
      where: "deviceUuid = ?",
      whereArgs: [uuid],
    );
    await db.delete("clusters", where: "ownerUuid = ?", whereArgs: [uuid]);

    _connectedEndpoints.clear();
    _activeConnections.clear();
    _createdCluster = null;
    _availableDevices.clear();
    _pendingConnections.clear();
    _pendingInvites.clear();

    notifyListeners();
  }
}
