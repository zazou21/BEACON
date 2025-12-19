part of 'nearby_connections.dart';

class NearbyConnectionsJoiner extends NearbyConnectionsBase {
  static final NearbyConnectionsJoiner _instance =
      NearbyConnectionsJoiner._internal();

  factory NearbyConnectionsJoiner() {
    return _instance;
  }

  NearbyConnectionsJoiner._internal();

  final Map<String, PendingConnection> _pendingConnections = {};
  final List<Map<String, dynamic>> _discoveredClusters = [];
  Cluster? _joinedCluster;
  ConnectionInfo? _pendingInviteInfo;
  String? _pendingInviteEndpointId;

  // Getters for reactive state
  Cluster? get joinedCluster => _joinedCluster;
  List<Map<String, dynamic>> get discoveredClusters =>
      List.unmodifiable(_discoveredClusters);
  ConnectionInfo? get pendingInviteInfo => _pendingInviteInfo;
  String? get pendingInviteEndpointId => _pendingInviteEndpointId;

  @override
  Future<void> startCommunication() async {
    print("[Nearby]: starting joiner");
    if (!await requestNearbyPermissions()) return;

    // Ensure repositories and device info are initialized
    if (clusterMemberRepository == null ||
        clusterRepository == null ||
        uuid == null) {
      print('[Nearby] Error: repositories or device UUID not initialized');
      return;
    }

    final existingMembership = await clusterMemberRepository!
        .getMembersByDeviceUuid(uuid!);

    if (existingMembership.isNotEmpty) {
      print('[Nearby] existing cluster membership found for joiner');
      final clusterId = existingMembership.first.clusterId;
      final cluster = await clusterRepository!.getClusterById(clusterId);

      if (cluster != null) {
        _joinedCluster = cluster;
        notifyListeners();
      }
      return;
    }

    await _startAdvertising();
    await _startDiscovery();
  }

  Future<void> _startAdvertising() async {
    print("[Nearby]: joiner advertising");

    // Ensure deviceName and uuid are initialized
    if (uuid == null || deviceName == null) {
      print(
        '[Nearby] Error: deviceName or uuid not initialized in _startAdvertising',
      );
      return;
    }

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

    // Ensure deviceName is initialized
    if (deviceName == null) {
      print('[Nearby] Error: deviceName not initialized in _startDiscovery');
      return;
    }

    try {
      await Nearby().startDiscovery(
        deviceName!,
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

    final parts = info.endpointName.split('|');
    if (parts.length >= 2) {
      final initiatorUuid = parts[0];
      final clusterId = parts[1];

      _pendingConnections[endpointId] = PendingConnection(
        initiatorUuid,
        clusterId,
      );

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
    // Ensure repositories and uuid are initialized
    if (clusterMemberRepository == null ||
        deviceRepository == null ||
        uuid == null) {
      print(
        '[Nearby] Error: repositories or uuid not initialized in _determineConnectionType',
      );
      return;
    }

    try {
      final isMember = await clusterMemberRepository!.isMemberOfCluster(
        clusterId,
        uuid!,
      );

      if (isMember) {
        // Auto-accept peer mesh connection
        print(
          '[Nearby] Auto-accepting peer mesh connection from $initiatorUuid',
        );

        await Nearby().acceptConnection(
          endpointId,
          onPayLoadRecieved: onPayloadReceived,
          onPayloadTransferUpdate: onPayloadUpdate,
        );

        await deviceRepository!.updateDeviceStatus(initiatorUuid, "Connected");
      } else {
        // Cluster invite - prompt user
        print('[Nearby] Cluster invite received from owner $initiatorUuid');

        _pendingInviteEndpointId = endpointId;
        _pendingInviteInfo = info;
        notifyListeners();
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

    // Ensure repositories and uuid are initialized
    if (clusterMemberRepository == null ||
        clusterRepository == null ||
        deviceRepository == null ||
        uuid == null) {
      print(
        '[Nearby] Error: repositories or uuid not initialized in _onConnectionResult',
      );
      return;
    }

    try {
      final isMember = await clusterMemberRepository!.isMemberOfCluster(
        clusterId,
        uuid!,
      );

      if (!isMember) {
        // First time joining
        await clusterMemberRepository!.insertMember(
          ClusterMember(clusterId: clusterId, deviceUuid: uuid!),
        );

        final cluster = await clusterRepository!.getClusterById(clusterId);
        if (cluster != null) {
          _joinedCluster = cluster;
        }
      }

      _activeConnections[endpointId] = remoteUuid;
      if (!_connectedEndpoints.contains(endpointId)) {
        _connectedEndpoints.add(endpointId);
      }

      await deviceRepository!.updateDeviceStatus(remoteUuid, "Connected");
      notifyListeners();
      print('[Nearby] Connection established successfully with $remoteUuid');
    } catch (e) {
      print('[Nearby] _onConnectionResult error: $e');
    }
  }

  Future<void> acceptInvite(String endpointId) async {
    print('[Nearby] acceptInvite called');

    // Ensure repositories and uuid are initialized
    if (clusterMemberRepository == null ||
        clusterRepository == null ||
        uuid == null) {
      print(
        '[Nearby] Error: repositories or uuid not initialized in acceptInvite',
      );
      return;
    }

    try {
      final pending = _pendingConnections.remove(endpointId);
      if (pending == null) {
        print('[Nearby] acceptInvite: no pending connection data');
        return;
      }

      final ownerUuid = pending.remoteUuid;
      final clusterId = pending.clusterId;

      await clusterMemberRepository!.insertMember(
        ClusterMember(clusterId: clusterId, deviceUuid: uuid!),
      );

      final cluster = await clusterRepository!.getClusterById(clusterId);
      if (cluster != null) {
        _joinedCluster = cluster;
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

    // Ensure repositories and uuid are initialized
    if (deviceRepository == null ||
        clusterMemberRepository == null ||
        uuid == null) {
      print(
        '[Nearby] Error: repositories or uuid not initialized in _onDisconnected',
      );
      return;
    }

    try {
      await deviceRepository!.updateDeviceStatus(devUuid, "Disconnected");
      await clusterMemberRepository!.deleteAllMembersByDevice(uuid!);
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

          // Ensure repositories and uuid are initialized
          if (clusterRepository == null ||
              clusterMemberRepository == null ||
              uuid == null) {
            print(
              '[Nearby] Error: repositories or uuid not initialized in joinCluster callback',
            );
            return;
          }

          try {
            final cluster = await clusterRepository!.getClusterById(clusterId);

            if (cluster != null) {
              print('[Nearby] joinCluster: cluster found');
              _joinedCluster = cluster;
            }

            await clusterMemberRepository!.insertMember(
              ClusterMember(clusterId: clusterId, deviceUuid: uuid!),
            );

            _activeConnections[id] = _joinedCluster!.ownerUuid;
            if (!_connectedEndpoints.contains(id)) _connectedEndpoints.add(id);

            await _loadDiscoveredClusters();
            notifyListeners();
          } catch (e) {
            print('[Nearby] joinCluster error: $e');
          }
        },
        onDisconnected: (id) async {
          final devUuid = _activeConnections.remove(id);
          _connectedEndpoints.remove(id);
          _joinedCluster = null;

          // Ensure repositories and uuid are initialized
          if (clusterMemberRepository != null && uuid != null) {
            try {
              await clusterMemberRepository!.deleteAllMembersByDevice(uuid!);
            } catch (e) {
              print('[Nearby] error in joinCluster onDisconnected: $e');
            }
          }
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

    // Ensure repositories and uuid are initialized before cleanup
    if (clusterMemberRepository != null && uuid != null) {
      try {
        await clusterMemberRepository!.deleteAllMembersByDevice(uuid!);
      } catch (e) {
        print('[Nearby] error deleting membership: $e');
      }
    }
    if (deviceRepository != null && ownerUuid != null) {
      try {
        await deviceRepository!.updateDeviceStatus(ownerUuid, "Disconnected");
      } catch (e) {
        print('[Nearby] error updating device status: $e');
      }
    }

    _joinedCluster = null;
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

      // Ensure deviceRepository is initialized
      if (deviceRepository == null) {
        print(
          '[Nearby] Error: deviceRepository not initialized in _onClusterFoundHandler',
        );
        return;
      }

      try {
        final existing = await deviceRepository!.getDeviceByUuid(deviceUuid);

        if (existing == null) {
          await deviceRepository!.insertDevice(
            Device(
              uuid: deviceUuid,
              deviceName: deviceName,
              endpointId: endpointId,
              status: "Available",
              isOnline: true,
              inRange: true,
            ),
          );
          print('[Nearby] New device added: $deviceName ($deviceUuid)');
        } else {
          existing.endpointId = endpointId;
          existing.status = "Available";
          existing.isOnline = true;
          existing.inRange = true;
          existing.lastSeen = DateTime.now();
          existing.updatedAt = DateTime.now();
          await deviceRepository!.updateDevice(existing);
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

      // Ensure clusterRepository is initialized
      if (clusterRepository == null) {
        print(
          '[Nearby] Error: clusterRepository not initialized in _onClusterFoundHandler',
        );
        return;
      }

      try {
        await clusterRepository!.insertCluster(
          Cluster(
            clusterId: clusterId,
            ownerUuid: ownerUuid,
            name: clusterName,
            ownerEndpointId: endpointId,
          ),
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

    // Ensure repositories and uuid are initialized
    if (clusterRepository == null ||
        clusterMemberRepository == null ||
        uuid == null) {
      print(
        '[Nearby] Error: repositories or uuid not initialized in _loadDiscoveredClusters',
      );
      return;
    }

    final clusters = await clusterRepository!.getAllClusters();
    final myMemberships = await clusterMemberRepository!.getMembersByDeviceUuid(
      uuid!,
    );

    _discoveredClusters.clear();

    for (var cluster in clusters) {
      final isMember = myMemberships.any(
        (m) => m.clusterId == cluster.clusterId,
      );
      if (isMember) continue;

      _discoveredClusters.add({
        "clusterId": cluster.clusterId,
        "clusterName": cluster.name,
        "endpointId": cluster.ownerEndpointId,
      });
    }
  }

  void _onClusterLost(String? endpointId) async {
    if (endpointId == null) return;
    print('[Nearby] cluster lost: $endpointId');

    try {
      //   // Find and delete cluster by endpoint
      //   if (clusterRepository == null) {
      //     print(
      //       '[Nearby] Error: clusterRepository not initialized in _onClusterLost',
      //     );
      //     return;
      //   }
      //   final clusters = await clusterRepository!.getAllClusters();
      //   for (var cluster in clusters) {
      //     if (cluster.ownerEndpointId == endpointId) {
      //       await clusterRepository!.deleteCluster(cluster.clusterId);
      //       break;
      //     }
      //   }

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
    debugPrint("[Nearby]: stopping all for joiner");

    await stopAdvertising();
    await stopDiscovery();

    for (final endpointId in List.of(_connectedEndpoints)) {
      await Nearby().disconnectFromEndpoint(endpointId);
    }

    _joinedCluster = null;
    _pendingConnections.clear();
    _discoveredClusters.clear();

    clearAllConnections();
  }
}
