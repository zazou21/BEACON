import 'package:flutter/material.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DashboardMode { initiator, joiner }

class DashboardViewModel extends ChangeNotifier {
  final DashboardMode mode;
  late final NearbyConnectionsBase beacon;

  // Initiator state
  Cluster? currentCluster;
  List<Device> availableDevices = [];
  List<Device> connectedDevices = [];

  // Joiner state
  List<Map<String, String>> discoveredClusters = [];
  Cluster? joinedCluster;
  List<Device> connectedDevicesToCluster = [];

  DashboardViewModel({required this.mode}) {
    _initializeBeacon();
  }

  void _initializeBeacon() {
    if (mode == DashboardMode.initiator) {
      beacon = NearbyConnectionsInitiator();
      beacon.addListener(_onBeaconStateChanged);
    } else {
      beacon = NearbyConnectionsJoiner();
      beacon.addListener(_onBeaconStateChanged);
    }
  }

  Future<void> initialize() async {
    await beacon.init();
    await beacon.startCommunication();

    if (mode == DashboardMode.joiner) {
      await _loadCurrentClusterJoiner();
      await _loadConnectedDevicesJoiner();
    } else {
      await _loadCurrentClusterInitiator();
      await _loadConnectedDevicesInitiator();
    }

    notifyListeners();
  }

  void _onBeaconStateChanged() {
    if (mode == DashboardMode.initiator) {
      _handleInitiatorStateChange();
    } else {
      _handleJoinerStateChange();
    }
  }

  void _handleInitiatorStateChange() {
    final initiator = beacon as NearbyConnectionsInitiator;
    currentCluster = initiator.createdCluster;
    availableDevices = initiator.availableDevices;
    _loadConnectedDevicesInitiator();
    notifyListeners();
  }

  void _handleJoinerStateChange() {
    final joiner = beacon as NearbyConnectionsJoiner;
    joinedCluster = joiner.joinedCluster;
    discoveredClusters = joiner.discoveredClusters;
    _loadConnectedDevicesJoiner();
    notifyListeners();
  }

  // INITIATOR METHODS

  Future<void> _loadCurrentClusterInitiator() async {
    final db = await DBService().database;
    final results = await db.query("clusters");
    final sp = await SharedPreferences.getInstance();
    final myUuid = sp.getString('device_uuid');

    final myClusters = results
        .where((map) => map['ownerUuid'] == myUuid)
        .toList();

    if (myClusters.isNotEmpty) {
      currentCluster = Cluster.fromMap(myClusters.first);
    } else {
      currentCluster = null;
    }

    notifyListeners();
  }

  Future<void> _loadConnectedDevicesInitiator() async {
    if (currentCluster == null) return;

    final db = await DBService().database;
    final members = await db.query(
      "cluster_members",
      where: "clusterId = ? AND deviceUuid != ?",
      whereArgs: [currentCluster!.clusterId, beacon.uuid],
    );

    if (members.isEmpty) {
      connectedDevices = [];
      notifyListeners();
      return;
    }

    final devicesMaps = await db.query(
      "devices",
      where: "uuid IN (${List.filled(members.length, '?').join(',')})",
      whereArgs: members.map((e) => e["deviceUuid"]).toList(),
    );

    connectedDevices = devicesMaps.map((map) => Device.fromMap(map)).toList();
    notifyListeners();
  }

  Future<void> inviteToCluster(Device device) async {
    final initiator = beacon as NearbyConnectionsInitiator;
    await initiator.inviteToCluster(
      device.endpointId,
      currentCluster!.clusterId,
    );
  }

  // JOINER METHODS

  Future<void> _loadCurrentClusterJoiner() async {
    final db = await DBService().database;
    final sp = await SharedPreferences.getInstance();
    final myUuid = sp.getString('device_uuid');

    final results = await db.query("cluster_members");
    final myClusters = results
        .where((map) => map['deviceUuid'] == myUuid)
        .toList();

    if (myClusters.isNotEmpty) {
      final clusterId = myClusters.first['clusterId'] as String;
      final clusterMaps = await db.query(
        "clusters",
        where: "clusterId = ?",
        whereArgs: [clusterId],
      );

      if (clusterMaps.isNotEmpty) {
        joinedCluster = Cluster.fromMap(clusterMaps.first);
      }
    } else {
      joinedCluster = null;
    }

    notifyListeners();
  }

  Future<void> _loadConnectedDevicesJoiner() async {
    if (joinedCluster == null) {
      connectedDevicesToCluster = [];
      notifyListeners();
      return;
    }

    connectedDevicesToCluster = await _fetchConnectedDevicesJoiner(
      joinedCluster!.clusterId,
      beacon.uuid,
    );

    notifyListeners();
  }

  Future<List<Device>> _fetchConnectedDevicesJoiner(
    String clusterId,
    String excludeUuid,
  ) async {
    final db = await DBService().database;
    final rows = await db.rawQuery(
      '''
      SELECT d.*
      FROM cluster_members cm
      JOIN devices d ON d.uuid = cm.deviceUuid
      WHERE cm.clusterId = ?
        AND cm.deviceUuid != ?
      ''',
      [clusterId, excludeUuid],
    );

    return rows.map((m) => Device.fromMap(m)).toList();
  }

  Future<void> joinCluster(Map<String, String> clusterInfo) async {
    final joiner = beacon as NearbyConnectionsJoiner;
    await joiner.joinCluster(
      clusterInfo["endpointId"]!,
      clusterInfo["clusterId"]!,
      clusterInfo["clusterName"]!,
    );
    
  }

  Future<void> acceptInvite(String endpointId) async {
    final joiner = beacon as NearbyConnectionsJoiner;
    await joiner.acceptInvite(endpointId);

    final db = await DBService().database;
    final joinerCluster = joiner.joinedCluster;
    if (joinerCluster != null) {
      joinedCluster = joinerCluster;
      await _loadConnectedDevicesJoiner();
    }
    notifyListeners();
  }

  void rejectInvite() {
    final joiner = beacon as NearbyConnectionsJoiner;
    joiner.rejectInvite();
  }

  Future<void> disconnectFromCluster() async {
    final joiner = beacon as NearbyConnectionsJoiner;
    await joiner.disconnectFromCluster();
    joinedCluster = null;
    connectedDevicesToCluster.clear();
    notifyListeners();
  }

  // SHARED METHODS

  void markOffline() {
    for (var endpointId in beacon.connectedEndpoints) {
      beacon.sendMessage(endpointId, "MARK_OFFLINE", {"uuid": beacon.uuid});
    }
  }

  void markOnline() {
    for (var endpointId in beacon.connectedEndpoints) {
      beacon.sendMessage(endpointId, "MARK_ONLINE", {"uuid": beacon.uuid});
    }
  }

  Future<void> printDatabaseContents() async {
    final db = await DBService().database;
    final devices = await db.query("devices");
    final clusters = await db.query("clusters");
    final members = await db.query("cluster_members");

    print("=== DATABASE CONTENTS ===");
    print("\nDevices (${devices.length}):");
    for (var d in devices) {
      print("  - ${d['deviceName']} (UUID: ${d['uuid']})");
      print("      Endpoint ID: ${d['endpointId']}");
      print("      Status: ${d['status']}");
      print("      In_Range: ${d['inRange']}");
    }

    print("\nClusters (${clusters.length}):");
    for (var c in clusters) {
      print(
        "  - ${c['name']} (ID: ${c['clusterId']}) owned by ${c['ownerUuid']}",
      );
    }

    print("\nCluster Members (${members.length}):");
    for (var m in members) {
      print("  - Device ${m['deviceUuid']} in Cluster ${m['clusterId']}");
    }
    print("========================\n");
  }

  Future<void> stopAll() async {
    await beacon.stopAll();
    currentCluster = null;
    availableDevices.clear();
    connectedDevices.clear();
    discoveredClusters.clear();
    joinedCluster = null;
    connectedDevicesToCluster.clear();
    notifyListeners();
  }

  String formatLastSeen(int millis) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 10) return "Active just now";
    if (diff.inMinutes < 1) return "Active ${diff.inSeconds}s ago";
    if (diff.inHours < 1) return "Active ${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "Active ${diff.inHours}h ago";
    if (diff.inDays < 7) return "Active ${diff.inDays}d ago";

    return "last seen ${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    beacon.removeListener(_onBeaconStateChanged);
    super.dispose();
  }
}
