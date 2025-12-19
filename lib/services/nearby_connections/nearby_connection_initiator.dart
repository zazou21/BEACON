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
  Future<void> startCommunication() async {
    print("[Nearby]: starting initiator");
    if (!await requestNearbyPermissions()) return;

    // Ensure repositories are initialized
    if (clusterRepository == null ||
        clusterMemberRepository == null ||
        deviceRepository == null ||
        uuid == null ||
        deviceName == null) {
      print('[Nearby] Error: repositories or device info not initialized');
      return;
    }

    final existingCluster = await clusterRepository!.getClusterByOwnerUuid(
      uuid!,
    );

    if (existingCluster != null) {
      print('[Nearby] existing cluster found for initiator');
      _createdCluster = existingCluster;
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
      ownerUuid: uuid!,
      ownerEndpointId: '',
      name: deviceName!,
    );

    _createdCluster = cluster;

    try {
      await clusterRepository!.insertCluster(cluster);
      await clusterMemberRepository!.insertMember(
        ClusterMember(clusterId: clusterId, deviceUuid: uuid!),
      );

      await _startAdvertising(clusterId, cluster.name);
      await _startDiscovery();
      notifyListeners();
    } catch (e) {
      print('[Nearby] error while creating cluster: $e');
    }
  }

  Future<void> _startAdvertising(String clusterId, String clusterName) async {
    print("[Nearby]: initiator advertising");

    // Ensure uuid is initialized
    if (uuid == null) {
      print('[Nearby] Error: uuid not initialized in _startAdvertising');
      return;
    }

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

    // Ensure repositories are initialized
    if (deviceRepository == null || clusterMemberRepository == null) {
      print(
        '[Nearby] Error: repositories not initialized in _onConnectionResult',
      );
      return;
    }

    try {
      await deviceRepository!.updateDeviceStatus(joinerUuid, "Connected");
      await clusterMemberRepository!.insertMember(
        ClusterMember(clusterId: clusterId, deviceUuid: joinerUuid),
      );

      _activeConnections[endpointId] = joinerUuid;
      if (!_connectedEndpoints.contains(endpointId)) {
        _connectedEndpoints.add(endpointId);
      }

      await _sendClusterInfo(clusterId);
      await _loadAvailableDevices();
      notifyListeners();
    } catch (e) {
      print('[Nearby] _onConnectionResult error: $e');
    }
  }

  Future<void> _sendClusterInfo(String clusterId) async {
    print("[Nearby] Sending CLUSTER_INFO for clusterId: $clusterId");

    // Ensure repositories and device info are initialized
    if (clusterMemberRepository == null ||
        deviceRepository == null ||
        uuid == null ||
        deviceName == null) {
      print(
        '[Nearby] Error: repositories or device info not initialized in _sendClusterInfo',
      );
      return;
    }

    final members = await clusterMemberRepository!.getMembersByClusterId(
      clusterId,
    );
    final memberUuids = members.map((m) => m.deviceUuid).toList();
    final devicesInCluster = await deviceRepository!.getDevicesByUuids(
      memberUuids,
    );

    final selfDevice = Device(
      uuid: uuid!,
      deviceName: deviceName!,
      endpointId: '',
      status: "Connected",
      lastSeen: DateTime.now(),
    );

    final devicesList = List<Map<String, dynamic>>.from(
      devicesInCluster.map((d) => d.toMap()),
    );
    devicesList.add(selfDevice.toMap());

    for (final epId in _connectedEndpoints) {
      final pending = _activeConnections[epId];
      if (pending == null) continue;

      final isMember = await clusterMemberRepository!.isMemberOfCluster(
        clusterId,
        pending,
      );

      if (!isMember) continue;

      sendMessage(epId, "CLUSTER_INFO", {
        "clusterId": clusterId,
        "senderUuid": uuid,
        "owner_device": selfDevice.toMap(),
        "members": members.map((m) => m.toMap()).toList(),
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

    // Ensure deviceRepository is initialized
    if (deviceRepository == null) {
      print(
        '[Nearby] Error: deviceRepository not initialized in _onEndpointFound',
      );
      return;
    }

    final existingDevice = await deviceRepository!.getDeviceByUuid(devUuid);

    if (existingDevice != null) {
      // Update existing device
      existingDevice.endpointId = endpointId;
      existingDevice.inRange = true;
      existingDevice.lastSeen = DateTime.now();
      existingDevice.updatedAt = DateTime.now();
      await deviceRepository!.updateDevice(existingDevice);
    } else {
      // Create new device
      final device = Device(
        uuid: devUuid,
        deviceName: name,
        endpointId: endpointId,
        status: "Available",
        lastSeen: DateTime.now(),
        inRange: true,
      );
      await deviceRepository!.insertDevice(device);
    }

    await _loadAvailableDevices();
    notifyListeners();
  }

  Future<void> _loadAvailableDevices() async {
    if (_createdCluster == null) return;

    // Ensure deviceRepository and uuid are initialized
    if (deviceRepository == null || uuid == null) {
      print(
        '[Nearby] Error: deviceRepository or uuid not initialized in _loadAvailableDevices',
      );
      return;
    }

    final devicesNotInCluster = await deviceRepository!.getDevicesNotInCluster(
      _createdCluster!.clusterId,
      uuid!,
    );

    _availableDevices.clear();
    _availableDevices.addAll(devicesNotInCluster);
  }

  void _onEndpointLost(String? endpointId) async {
    print('[Nearby] endpoint lost: $endpointId');
    if (endpointId == null) return;

    // Ensure deviceRepository is initialized
    if (deviceRepository == null) {
      print(
        '[Nearby] Error: deviceRepository not initialized in _onEndpointLost',
      );
      return;
    }

    try {
      await deviceRepository!.updateDeviceInRange(endpointId, false);
      await _loadAvailableDevices();
      notifyListeners();
    } catch (e) {
      print('[Nearby] _onEndpointLost error: $e');
    }
  }

  void _onDisconnected(String endpointId) async {
    print('[Nearby] disconnected from $endpointId');
    final devUuid = _activeConnections.remove(endpointId);
    _connectedEndpoints.remove(endpointId);

    if (devUuid == null) return;

    // Ensure repositories are initialized
    if (deviceRepository == null || clusterMemberRepository == null) {
      print('[Nearby] Error: repositories not initialized in _onDisconnected');
      return;
    }

    try {
      await deviceRepository!.updateDeviceStatus(devUuid, "Disconnected");
      await clusterMemberRepository!.deleteMember(
        _createdCluster!.clusterId,
        devUuid,
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

    // Ensure repositories are initialized
    if (deviceRepository == null || clusterMemberRepository == null) {
      print(
        '[Nearby] Error: repositories not initialized in _onInviteConnectionResult',
      );
      return;
    }

    try {
      await deviceRepository!.updateDeviceStatus(joinerUuid, "Connected");
      await clusterMemberRepository!.insertMember(
        ClusterMember(clusterId: clusterId, deviceUuid: joinerUuid),
      );

      _activeConnections[endpointId] = joinerUuid;
      if (!_connectedEndpoints.contains(endpointId)) {
        _connectedEndpoints.add(endpointId);
      }

      await _sendClusterInfo(clusterId);
      await _loadAvailableDevices();
      notifyListeners();
    } catch (e) {
      print('[Nearby] _onInviteConnectionResult error: $e');
    }
  }

  void _onInviteDisconnected(String endpointId) async {
    print('[Nearby] invite disconnected from $endpointId');
    final devUuid = _activeConnections.remove(endpointId);
    _connectedEndpoints.remove(endpointId);

    if (devUuid == null) return;

    // Ensure repositories are initialized
    if (deviceRepository == null || clusterMemberRepository == null) {
      print(
        '[Nearby] Error: repositories not initialized in _onInviteDisconnected',
      );
      return;
    }

    try {
      await deviceRepository!.updateDeviceStatus(devUuid, "Disconnected");
      await clusterMemberRepository!.deleteMember(
        _createdCluster!.clusterId,
        devUuid,
      );
      await _loadAvailableDevices();
      notifyListeners();
    } catch (e) {
      print('[Nearby] disconnect cleanup error: $e');
    }
  }

  Future<void> transferOwnershipBeforeDisconnect() async {
    if (_createdCluster == null || _connectedEndpoints.isEmpty) return;

    // Ensure repositories and uuid are initialized
    if (clusterMemberRepository == null ||
        deviceRepository == null ||
        uuid == null) {
      print(
        '[Nearby] Error: repositories or uuid not initialized in transferOwnershipBeforeDisconnect',
      );
      return;
    }

    print('[Nearby] Transferring cluster ownership before disconnect');

    final newOwnerEndpointId = _connectedEndpoints.first;
    final newOwnerUuid = _activeConnections[newOwnerEndpointId];

    if (newOwnerUuid == null) return;

    final members = await clusterMemberRepository!.getMembersByClusterId(
      _createdCluster!.clusterId,
    );
    final memberUuids = members.map((m) => m.deviceUuid).toList();
    final devices = await deviceRepository!.getDevicesByUuids(memberUuids);

    sendMessage(newOwnerEndpointId, "TRANSFER_OWNERSHIP", {
      "clusterId": _createdCluster!.clusterId,
      "clusterName": _createdCluster!.name,
      "newOwnerUuid": newOwnerUuid,
      "oldOwnerUuid": uuid,
      "members": members.map((m) => m.toMap()).toList(),
      "devices": devices.map((d) => d.toMap()).toList(),
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
    debugPrint("[Nearby]: stopping all for initiator");

    await transferOwnershipBeforeDisconnect();
    await stopAdvertising();
    await stopDiscovery();

    for (final endpointId in List.of(_connectedEndpoints)) {
      await Nearby().disconnectFromEndpoint(endpointId);
    }

    if (clusterMemberRepository != null && uuid != null) {
      await clusterMemberRepository!.deleteAllMembersByDevice(uuid!);
    }

    if (clusterRepository != null && uuid != null) {
      await clusterRepository!.deleteClusterByOwner(uuid!);
    }

    _createdCluster = null;
    _availableDevices.clear();
    _pendingConnections.clear();
    _pendingInvites.clear();

    clearAllConnections();
  }
}
