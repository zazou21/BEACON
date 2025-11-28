import 'package:flutter/material.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DashboardMode { initiator, joiner }

Future<void> saveModeOnce(DashboardMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('dashboard_mode');

  if (savedMode == null || savedMode.isEmpty) {
    await prefs.setString('dashboard_mode', mode.name);
  }
}

class DashboardPage extends StatefulWidget {
  final DashboardMode mode;
  const DashboardPage({super.key, required this.mode});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  late final NearbyConnectionsBase beacon;

  // Initiator state
  Cluster? currentCluster;
  List<Device> availableDevices = [];
  List<Device> connectedDevices = [];

  // Joiner state
  List<Map<String, String>> discoveredClusters = [];
  Cluster? joinedCluster;
  List<Device> connectedDevicesToCluster = [];

  @override
  void initState() {
    super.initState();
    saveModeOnce(widget.mode);
    print('[Dashboard] Initializing in ${widget.mode} mode');
    _initializeBeacon();
    _setupBeacon();
    WidgetsBinding.instance.addObserver(this);
  }

  void _initializeBeacon() {
    if (widget.mode == DashboardMode.initiator) {
      beacon = NearbyConnectionsInitiator();
    } else {
      beacon = NearbyConnectionsJoiner();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _markOffline();
    } else if (state == AppLifecycleState.resumed) {
      _markOnline();
    }
  }

  void _markOffline() {
    for (var endpointId in beacon.connectedEndpoints) {
      beacon.sendMessage(endpointId, "MARK_OFFLINE", {"uuid": beacon.uuid});
    }
  }

  void _markOnline() {
    for (var endpointId in beacon.connectedEndpoints) {
      beacon.sendMessage(endpointId, "MARK_ONLINE", {"uuid": beacon.uuid});
    }
  }

  Future<void> _setupBeacon() async {
    await beacon.init();

    if (widget.mode == DashboardMode.joiner) {
      _setupJoinerCallbacks();
      await beacon.startCommunication();
      await _loadCurrentClusterJoiner();
      await _loadConnectedDevicesJoiner();
    } else {
      _setupInitiatorCallbacks();
      await beacon.startCommunication();
      await _loadCurrentClusterInitiator();
      await _loadConnectedDevicesInitiator();
    }

    setState(() {});
  }

  void _setupInitiatorCallbacks() {
    final initiator = beacon as NearbyConnectionsInitiator;

    initiator.onDeviceFound = _onDeviceFoundHandler;
    initiator.onClusterJoinedInitiatorSide =
        _onClusterJoinedInitiatorSideHandler;
    beacon.onStatusChange = _onStatusChangeHandler;
  }

  void _setupJoinerCallbacks() {
    final joiner = beacon as NearbyConnectionsJoiner;

    joiner.onClusterFound = _onClusterFoundHandler;
    joiner.onConnectionRequest = _onConnectionRequestHandler;
    joiner.onClusterJoinedJoinerSide = _onClusterJoinedJoinerSideHandler;
    beacon.onStatusChange = _onStatusChangeHandler;
    beacon.onClusterInfoSent = _onClusterInfoSentHandler;
  }

  // INITIATOR HANDLERS

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

    setState(() {});
  }

  Future<void> _loadConnectedDevicesInitiator() async {
    if (currentCluster == null) return;

    final db = await DBService().database;
    final members = await db.query(
      "cluster_members",
      where: "clusterId = ? AND deviceUuid != ?",
      whereArgs: [currentCluster!.clusterId, beacon.uuid],
    );

    final devicesMaps = await db.query(
      "devices",
      where: "uuid IN (${List.filled(members.length, '?').join(',')})",
      whereArgs: members.map((e) => e["deviceUuid"]).toList(),
    );

    connectedDevices = devicesMaps.map((map) => Device.fromMap(map)).toList();
    setState(() {});
  }

  void _removeConnectedFromAvailable() {
    availableDevices.removeWhere(
      (d) => connectedDevices.any((cd) => cd.endpointId == d.endpointId),
    );
  }

  void _onDeviceFoundHandler(Device d) {
    final exists = availableDevices.any((x) => x.endpointId == d.endpointId);
    if (!exists) {
      availableDevices.add(d);
      print("Device Found: ${d.deviceName} (${d.uuid})");
      setState(() {});
    }
  }

  void _onClusterJoinedInitiatorSideHandler() async {
    await _loadConnectedDevicesInitiator();
    _removeConnectedFromAvailable();
    setState(() {});
  }

  void _onClusterInfoSentHandler() async {
    if (joinedCluster == null) return;
    final clusterId = joinedCluster!.clusterId;
    final db = await DBService().database;
    final rows = await db.rawQuery(
      '''
          SELECT d.*
          FROM cluster_members cm
          JOIN devices d ON d.uuid = cm.deviceUuid
          WHERE cm.clusterId = ?
            AND cm.deviceUuid != ?
        ''',
      [clusterId, beacon.uuid],
    );

    print("Connected Devices to Cluster Rows: $rows");

    connectedDevicesToCluster = rows.map((map) => Device.fromMap(map)).toList();
    // print("Connected Devices to Cluster Loaded: $connectedDevicesToCluster");

    setState(() {});
  }

  Future<void> _inviteToCluster(Device device) async {
    final initiator = beacon as NearbyConnectionsInitiator;
    await initiator.inviteToCluster(
      device.endpointId,
      currentCluster!.clusterId,
    );
  }

  // JOINER HANDLERS

  Future<void> _loadCurrentClusterJoiner() async {
    print('[Dashboard] Loading current cluster for joiner');
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

    setState(() {});
  }

  Future<void> _loadConnectedDevicesJoiner() async {
    if (joinedCluster == null) return;

    connectedDevicesToCluster = await _fetchConnectedDevicesJoiner(
      joinedCluster!.clusterId,
      beacon.uuid,
    );

    print("Connected Devices to Cluster Loaded: $connectedDevicesToCluster");
    setState(() {});
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

  void _onClusterFoundHandler(Map<String, String> clusterInfo) {
    final clusterId = clusterInfo["clusterId"];
    if (clusterId == null) return;

    final exists = discoveredClusters.any((c) => c["clusterId"] == clusterId);
    if (exists) return;

    discoveredClusters.add(clusterInfo);
    print("Cluster Found: $clusterInfo");
    setState(() {});
  }

  void _onClusterJoinedJoinerSideHandler(String clusterId) async {
    print("Joined Cluster (Joiner Side): $clusterId");

    discoveredClusters.removeWhere((c) => c["clusterId"] == clusterId);

    final db = await DBService().database;
    final clusterMaps = await db.query(
      "clusters",
      where: "clusterId = ?",
      whereArgs: [clusterId],
    );

    if (clusterMaps.isNotEmpty) {
      joinedCluster = Cluster.fromMap(clusterMaps.first);
      setState(() {});
    }
  }

  void _onConnectionRequestHandler(String endpointId, ConnectionInfo info) {
    print("Connection Request from $endpointId");

    final parts = info.endpointName.split("|");
    if (parts.length < 2) {
      print("Malformed endpointName from initiator.");
      return;
    }

    final clusterId = parts[1];
    final clusterName = "Cluster $clusterId";

    _showInviteDialog(endpointId, clusterName, clusterId);
  }

  Future<void> _joinCluster(Map<String, String> clusterInfo) async {
    final joiner = beacon as NearbyConnectionsJoiner;
    await joiner.joinCluster(
      clusterInfo["endpointId"]!,
      clusterInfo["clusterId"]!,
      clusterInfo["clusterName"]!,
    );
  }

  Future<void> _disconnectFromCluster() async {
    final joiner = beacon as NearbyConnectionsJoiner;
    await joiner.disconnectFromCluster();

    setState(() {
      joinedCluster = null;
      connectedDevicesToCluster.clear();
    });
  }

  // SHARED HANDLERS

  void _onStatusChangeHandler() async {
    if (widget.mode == DashboardMode.initiator) {
      await _loadConnectedDevicesInitiator();
    } else if (widget.mode == DashboardMode.joiner) {
      await _loadConnectedDevicesJoiner();
    }
    setState(() {});
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

              final joiner = beacon as NearbyConnectionsJoiner;
              await joiner.acceptInvite(endpointId);

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

  // UTILITY METHODS

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

  Future<void> _printDatabaseContents() async {
    final db = await DBService().database;
    final devices = await db.query("devices");
    final clusters = await db.query("clusters");
    final members = await db.query("cluster_members");

    print("=== DATABASE CONTENTS ===");
    print("\nDevices (${devices.length}):");
    for (var d in devices) {
      print("  - ${d['deviceName']} (UUID: ${d['uuid']})");
      print("      Endpoint ID: ${d['endpointId']}");
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

  Future<void> _stopAll() async {
    await beacon.stopAll();
    if (!mounted) return;

    setState(() {
      currentCluster = null;
      availableDevices.clear();
      connectedDevices.clear();
      discoveredClusters.clear();
      joinedCluster = null;
      connectedDevicesToCluster.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _printDatabaseContents,
            child: const Text("Print DB"),
          ),
          TextButton(onPressed: _stopAll, child: const Text("Stop All")),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (currentCluster != null) _buildClusterCard(currentCluster!),

          if (widget.mode == DashboardMode.initiator)
            _buildInitiatorView()
          else
            _buildJoinerView(),
        ],
      ),
    );
  }

  Widget _buildClusterCard(Cluster cluster) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.wifi_tethering),
        title: Text("Your Cluster: ${cluster.name}'s Network"),
        subtitle: Text("Cluster ID: ${cluster.clusterId}"),
      ),
    );
  }

  Widget _buildInitiatorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader("Available Devices"),

        if (availableDevices.isEmpty)
          _buildEmptyState("No devices found")
        else
          ...availableDevices.map((d) => _buildAvailableDeviceCard(d)),

        const SizedBox(height: 20),
        _buildSectionHeader("Connected Devices"),

        if (connectedDevices.isEmpty)
          _buildEmptyState("No connected devices yet")
        else
          ...connectedDevices.map((d) => _buildConnectedDeviceCard(d)),
      ],
    );
  }

  Widget _buildJoinerView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader("Discovered Clusters"),

        if (discoveredClusters.isEmpty)
          _buildEmptyState("No clusters found")
        else
          ...discoveredClusters.map((c) => _buildDiscoveredClusterCard(c)),

        const SizedBox(height: 20),
        _buildSectionHeader("Joined Cluster"),

        if (joinedCluster == null)
          _buildEmptyState("No connected cluster yet")
        else
          _buildJoinedClusterCard(joinedCluster!),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildAvailableDeviceCard(Device device) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.smartphone),
        title: Text(device.deviceName),
        trailing: TextButton(
          onPressed: () => _inviteToCluster(device),
          child: const Text("Invite"),
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceCard(Device device) {
    return Card(
      child: ListTile(
        leading: _buildDeviceIcon(device.isOnline),
        title: Text(device.deviceName),
        subtitle: device.isOnline
            ? const Text("Online", style: TextStyle(color: Colors.green))
            : Text(formatLastSeen(device.lastSeen.millisecondsSinceEpoch)),
        trailing: _buildDeviceMenu(),
      ),
    );
  }

  Widget _buildDiscoveredClusterCard(Map<String, String> clusterInfo) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.people),
        title: Text("${clusterInfo["clusterName"]}'s Network"),
        trailing: TextButton(
          onPressed: () => _joinCluster(clusterInfo),
          child: const Text("Join"),
        ),
      ),
    );
  }

  Widget _buildJoinedClusterCard(Cluster cluster) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildClusterIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "${cluster.name}'s Network",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.campaign, color: Colors.blueAccent),
                  onPressed: () {},
                  tooltip: "Broadcast",
                ),
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  onPressed: _disconnectFromCluster,
                  tooltip: "Leave",
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (connectedDevicesToCluster.isNotEmpty)
              Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: connectedDevicesToCluster.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey[300]),
              itemBuilder: (context, index) {
                final d = connectedDevicesToCluster[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _buildDeviceIcon(d.isOnline),
                  title: Text(d.deviceName),
                  subtitle: d.isOnline
                      ? const Text(
                          "Online",
                          style: TextStyle(color: Colors.green),
                        )
                      : Text(
                          formatLastSeen(d.lastSeen.millisecondsSinceEpoch),
                          style: const TextStyle(color: Colors.grey),
                        ),
                  trailing: _buildDeviceMenu(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceIcon(bool isOnline) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.smartphone, size: 40, color: Colors.grey[700]),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.wifi, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildClusterIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.people, size: 35, color: Colors.grey[700]),
        Positioned(
          right: -4,
          top: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.wifi, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'chat') {}
        if (value == 'quick_message') {}
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'chat', child: Text('Chat')),
        PopupMenuItem(
          value: 'quick_message',
          child: Text('Send Quick Message'),
        ),
      ],
    );
  }
}
