import 'package:flutter/material.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beacon_project/models/dashboard_mode.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardMode mode;
  late final NearbyConnectionsBase nearby;

  // Initiator state
  Cluster? currentCluster;
  List<Device> availableDevices = [];
  List<Device> connectedDevices = [];

  // Joiner state
  Cluster? joinedCluster;
  List<Map<String, String>> discoveredClusters = [];
  List<Device> connectedDevicesToCluster = [];

  DashboardViewModel({required this.mode}) {
    _dashboardSetup();
  }

  void _dashboardSetup() {
    if (mode == DashboardMode.initiator) {
      nearby = NearbyConnectionsInitiator();
      nearby.addListener(_onNearbyStateChanged);
    } else {
      nearby = NearbyConnectionsJoiner();
      nearby.addListener(_onNearbyStateChanged);
    }
  }

  Future<void> initializeNearby() async {
    await nearby.init();
    await nearby.startCommunication(); // start advertising and discovering

    if (mode == DashboardMode.joiner) {
      await _loadCurrentClusterJoiner();
      await _loadConnectedDevicesJoiner();
    } else {
      await _loadCurrentClusterInitiator();
      await _loadConnectedDevicesInitiator();
    }

    notifyListeners();
  }

  void onNearbyStateChanged() {
    _onNearbyStateChanged();
  }

  // when notifyListeners is called from nearbyconnection service
  void _onNearbyStateChanged() {
    if (mode == DashboardMode.initiator) {
      _handleInitiatorStateChange();
    } else {
      _handleJoinerStateChange();
    }
  }

  void _handleInitiatorStateChange() {
    final initiator = nearby as NearbyConnectionsInitiator;
    currentCluster = initiator.createdCluster;
    availableDevices = initiator.availableDevices;
    _loadConnectedDevicesInitiator();
    notifyListeners();
  }

  void _handleJoinerStateChange() {
    final joiner = nearby as NearbyConnectionsJoiner;
    joinedCluster = joiner.joinedCluster;
    discoveredClusters = joiner.discoveredClusters;
    _loadConnectedDevicesJoiner();
    notifyListeners();
  }

  // INITIATOR METHODS

  Future<void> _loadCurrentClusterInitiator() async {
    print("[DASHBOARD]: loading current cluster");
    // find cluster owned by me
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
    print("[DASHBOARD]: loading connected devices");
    if (currentCluster == null) return;

    final db = await DBService().database;
    final members = await db.query(
      "cluster_members",
      where: "clusterId = ? AND deviceUuid != ?",
      whereArgs: [currentCluster!.clusterId, nearby.uuid],
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
    print("[DASHBOARD]: inviting to cluster");
    final initiator = nearby as NearbyConnectionsInitiator;
    await initiator.inviteToCluster(
      device.endpointId,
      currentCluster!.clusterId,
    );
  }

  // JOINER METHODS

  Future<void> _loadCurrentClusterJoiner() async {
    print("[DASHBOARD]: loading current cluster");

    // find cluster where i am a member of
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
    print("[DASHBOARD]: loading connected devices");

    if (joinedCluster == null) {
      connectedDevicesToCluster = [];
      notifyListeners();
      return;
    }

    final db = await DBService().database;
    final rows = await db.rawQuery(
      '''
    SELECT d.*
    FROM cluster_members cm
    JOIN devices d ON d.uuid = cm.deviceUuid
    WHERE cm.clusterId = ?
      AND cm.deviceUuid != ?
    ''',
      [joinedCluster!.clusterId, nearby.uuid],
    );

    connectedDevicesToCluster = rows.map((m) => Device.fromMap(m)).toList();

    notifyListeners();
  }

  Future<void> joinCluster(Map<String, String> clusterInfo) async {
    print("[DASHBOARD]: joining cluster");
    final joiner = nearby as NearbyConnectionsJoiner;
    await joiner.joinCluster(
      clusterInfo["endpointId"]!,
      clusterInfo["clusterId"]!,
      clusterInfo["clusterName"]!,
    );
  }

  Future<void> acceptInvite(String endpointId) async {
    print("[DASHBOARD]: accepting invite");
    final joiner = nearby as NearbyConnectionsJoiner;
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
    print("[DASHBOARD]: rejecting invite");
    final joiner = nearby as NearbyConnectionsJoiner;
    joiner.rejectInvite();
  }

  Future<void> disconnectFromCluster() async {
    print("[DASHBOARD]: disconnecting from cluster");
    final joiner = nearby as NearbyConnectionsJoiner;
    await joiner.disconnectFromCluster();
    joinedCluster = null;
    connectedDevicesToCluster.clear();
    notifyListeners();
  }

  // SHARED METHODS

  void markOffline() {
    print("[DASHBOARD]: marking offline");
    for (var endpointId in nearby.connectedEndpoints) {
      print("[DASHBOARD]: marking offline to $endpointId");
      nearby.sendMessage(endpointId, "MARK_OFFLINE", {"uuid": nearby.uuid});
    }
  }

  void markOnline() {
    print("[DASHBOARD]: marking online");
    for (var endpointId in nearby.connectedEndpoints) {
      nearby.sendMessage(endpointId, "MARK_ONLINE", {"uuid": nearby.uuid});
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
    print("[DASHBOARD]: stopping all");
    await nearby.stopAll();
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
    nearby.removeListener(_onNearbyStateChanged);
    super.dispose();
  }
}
