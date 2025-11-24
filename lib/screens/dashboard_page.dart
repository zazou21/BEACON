import 'package:flutter/material.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:sqflite/sqflite.dart';

enum DashboardMode { initiator, joiner }

class DashboardPage extends StatefulWidget {
  final DashboardMode mode;
  const DashboardPage({super.key, required this.mode});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final beacon = NearbyConnections();

  List<Device> availableDevices = [];
  List<Device> connectedDevices = [];
  List<Map<String, String>> discoveredClusters = [];
  List<Cluster> joinedClusters = [];
  Cluster? currentCluster;

  @override
  void initState() {
    super.initState();
    _setupBeacon();
  }

  Future<void> _setupBeacon() async {
    await beacon.init();

    if (widget.mode == DashboardMode.joiner) {
      await beacon.joinCommunication();
    } else {
      await beacon.initiateCommunication();
    }

    // for the discovery of devices & clusters
    beacon.onDeviceFound = _onDeviceFoundHandler; // for initiator mode
    beacon.onClusterFound = _onClusterFoundHandler; // for joiner mode

    beacon.onConnectionRequest =
        _onConnectionRequestHandler; // show invite dialog (joiner)

    beacon.onClusterJoinedInitiatorSide =
        _onClusterJoinedInitiatorSideHandler; // update connected devices list (initiator)

    beacon.onClusterJoinedJoinerSide =
        _onClusterJoinedJoinerSideHandler; // update joined clusters list (joiner)

    await _loadCurrentCluster();
    setState(() {});
  }

  Future<void> _loadCurrentCluster() async {
    final db = await DBService().database;
    final results = await db.query("clusters");
    if (results.isNotEmpty) {
      currentCluster = Cluster.fromMap(results.first);
      if (widget.mode == DashboardMode.initiator) {
        await _loadConnectedDevices();
      }
    }
    setState(() {});
  }

  // load connected devices excluding self & remove user from availableDevices list
  Future<void> _loadConnectedDevices() async {
    if (currentCluster == null) return;
    final db = await DBService().database;
    // Get members in current cluster except itself
    final members = await db.query(
      "cluster_members",
      where: "clusterId = ? AND deviceUuid != ?",
      whereArgs: [currentCluster!.clusterId, beacon.uuid],
    );
    // Map to Device if needed; here assuming device info is in "devices" table
    final devicesMaps = await db.query(
      "devices",
      where: "uuid IN (${List.filled(members.length, '?').join(',')})",
      whereArgs: members.map((e) => e["deviceUuid"]).toList(),
    );

    connectedDevices = devicesMaps.map((map) => Device.fromMap(map)).toList();
    availableDevices.removeWhere(
      (d) => connectedDevices.any((cd) => cd.endpointId == d.endpointId),
    );
    print("Connected Devices Loaded: $connectedDevices");
    setState(() {});
  }

  void _onDeviceFoundHandler(Device d) {
    final exists = availableDevices.any((x) => x.endpointId == d.endpointId);
    if (!exists) {
      setState(() => availableDevices.add(d));
    }

    print("Device Found: ${d.deviceName} (${d.uuid})");
    setState(() {});
  }

  // load clusters from database (joiner mode ) and add them to discoveredClusters list
  // endpoint id msh fl database, 7ases we should add it, bas msh 2ader // mesh hases lazem ne add it

  void _onClusterFoundHandler(Map<String, String> clusterInfo) {
    discoveredClusters.add(clusterInfo);
    print("Cluster Found: $clusterInfo");
    setState(() {});
  }

  void _onClusterJoinedInitiatorSideHandler(String clusterId) async {
    print("Joined Cluster: $clusterId");
    await _loadConnectedDevices();
    setState(() {});
  }

  void _onClusterJoinedJoinerSideHandler(String clusterId) async {
    print("Joined Cluster (Joiner Side): $clusterId");
    final db = await DBService().database;
    final clusterMaps = await db.query(
      "clusters",
      where: "clusterId = ?",
      whereArgs: [clusterId],
    );
    if (clusterMaps.isNotEmpty) {
      final cluster = Cluster.fromMap(clusterMaps.first);
      joinedClusters.add(cluster);
      setState(() {});
    }
  }

  // show invite dialog on connection request
  void _onConnectionRequestHandler(String endpointId, ConnectionInfo info) {
    print("Connection Request from $endpointId");

    // Format: <initiatorUuid>|<clusterId>
    final parts = info.endpointName.split("|");

    if (parts.length < 2) {
      print("Malformed endpointName from initiator.");
      return;
    }

    final clusterId = parts[1];
    final clusterName = "Cluster $clusterId"; // or look up name in DB

    _showInviteDialog(endpointId, clusterName, clusterId);
  }

  void _showInviteDialog(
    String endpointId,
    String clusterName,
    String clusterId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Network Invitation"),
        content: Text("Do you want to join $clusterName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Reject"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              await beacon.acceptInvite(endpointId);

              // Optional: Update DB
              final db = await DBService().database;
              await db.insert("cluster_members", {
                "clusterId": clusterId,
                "deviceUuid": beacon.uuid,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  // This method invites a joiner device to the cluster (initiator)
  void _inviteJoiner(String endpointId, String joinerUuid) {
    if (currentCluster == null) return;
    beacon.sendControlMessage(endpointId, {
      "type": "cluster_invite",
      "clusterId": currentCluster!.clusterId,
      "clusterName": currentCluster!.name,
    });
  }

  // This method prints database contents for debugging purposes
  Future<void> _printDatabaseContents() async {
    final db = await DBService().database;
    final devices = await db.query("devices");
    final clusters = await db.query("clusters");
    final members = await db.query("cluster_members");

    print("Devices: $devices");
    print("Clusters: $clusters");
    print("Cluster Members: $members");
  }

  // UI build function with connectedDevices section for initiator mode
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          TextButton(
            onPressed: _printDatabaseContents,
            child: const Text("Print DB"),
          ),
          TextButton(
            onPressed: () async {
              await beacon.stopAll();
              if (!mounted) return;
              setState(() {
                currentCluster = null;
                availableDevices.clear();
                connectedDevices.clear();
              });
            },
            child: const Text("Stop All"),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (currentCluster != null)
            Card(
              child: ListTile(
                title: Text("Your Cluster: ${currentCluster!.name}"),
                subtitle: Text("ID: ${currentCluster!.clusterId}"),
              ),
            ),

          if (widget.mode == DashboardMode.initiator) ...[
            const SizedBox(height: 20),
            const Text("Available Devices"),
            ...availableDevices.map(
              (d) => Card(
                child: ListTile(
                  title: Text(d.deviceName),
                  subtitle: Text("UUID: ${d.uuid}"),
                  trailing: TextButton(
                    onPressed: () => _inviteJoiner(d.endpointId, d.uuid),
                    child: const Text("Invite"),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text("Connected Devices"),
            ...connectedDevices.map(
              (d) => Card(
                child: ListTile(
                  title: Text(d.deviceName),
                  subtitle: Text("UUID: ${d.uuid}"),
                ),
              ),
            ),
          ],

          if (widget.mode == DashboardMode.joiner) ...[
            const SizedBox(height: 20),
            const Text("Discovered Clusters"),
            ...discoveredClusters.map(
              (c) => Card(
                child: ListTile(
                  title: Text(c["clusterName"] ?? "Unknown Cluster"),
                  subtitle: Text("ID: ${c["clusterId"]}"),
                  trailing: TextButton(
                    onPressed: () =>
                        beacon.joinCluster(c["endpointId"]!, c["clusterId"]!),
                    child: const Text("Join"),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Joined Clusters"),
            ...joinedClusters.map(
              (c) => Card(
                child: ListTile(
                  title: Text(c.name),
                  subtitle: Text("ID: ${c.clusterId}"),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
