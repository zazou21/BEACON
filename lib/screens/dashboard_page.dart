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

  // save only if nothing is stored yet
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
  final beacon = NearbyConnections();

  // initiator
  Cluster? currentCluster;
  List<Device> availableDevices = [];
  List<Device> connectedDevices = [];

  // joiner
  List<Map<String, String>> discoveredClusters = [];
  Cluster? joinedCluster = null;
  List<Device> connectedDevicesToCluster = [];

  @override
  void initState() {
    super.initState();
    saveModeOnce(widget.mode);
    print('[Dashboard] Initializing in ${widget.mode} mode');
    _setupBeacon();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      beacon.markOffline();
    } else if (state == AppLifecycleState.resumed) {
      beacon.markOnline();
    }
  }

  Future<void> _setupBeacon() async {
    await beacon.init();

    if (widget.mode == DashboardMode.joiner) {
      print('[Dashboard] Joiner mode: starting communication');
      await beacon.joinCommunication();
      await _loadCurrentClusterJoiner();
      await _loadConnectedDevicesJoiner();
    } else {
      print('[Dashboard] Initiator mode: starting communication');
      await beacon.initiateCommunication();
      await _loadCurrentClusterInitiator();
      await _loadConnectedDevicesInitiator();
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

    beacon.onClusterInfoSent = _onClusterInfoSentHandler;

    beacon.onStatusChange = _onStatusChangeHandler;

    setState(() {});
  }

  // check if user is member in any cluster (joiner mode)
  Future<void> _loadCurrentClusterJoiner() async {
    print('[Dashboard] Loading current cluster for joiner');
    final db = await DBService().database;
    // final results = await db.query("clusters");

    final sp = await SharedPreferences.getInstance();

    final myUuid = sp.getString('device_uuid');
    // filter the cluster where im a member
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
    connectedDevicesToCluster = await fetchConnectedDevicesJoiner(
      joinedCluster!.clusterId,
      beacon.uuid,
    );

    print("Connected Devices to Cluster Loaded: $connectedDevicesToCluster");
    setState(() {});
  }

  Future<void> _loadCurrentClusterInitiator() async {
    final db = await DBService().database;
    final results = await db.query("clusters");

    final sp = await SharedPreferences.getInstance();

    final myUuid = sp.getString('device_uuid');

    // filter the cluster where im the owner
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

  // load connected devices excluding self & remove user from availableDevices list
  Future<void> _loadConnectedDevicesInitiator() async {
    if (currentCluster == null) return;
    final db = await DBService().database;
    // Get members in current cluster except itself
    final members = await db.query(
      "cluster_members",
      where: "clusterId = ? AND deviceUuid != ?",
      whereArgs: [currentCluster!.clusterId, beacon.uuid],
    );
    // Map to Device
    final devicesMaps = await db.query(
      "devices",
      where: "uuid IN (${List.filled(members.length, '?').join(',')})",
      whereArgs: members.map((e) => e["deviceUuid"]).toList(),
    );

    connectedDevices = devicesMaps.map((map) => Device.fromMap(map)).toList();

    print("Connected Devices Loaded: $connectedDevices");
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
      setState(() => availableDevices.add(d));
    }

    print("Device Found: ${d.deviceName} (${d.uuid})");
    setState(() {});
  }

  // load clusters from database (joiner mode ) and add them to discoveredClusters list
  // endpoint id msh fl database, 7ases we should add it, bas msh 2ader

  void _onClusterFoundHandler(Map<String, String> clusterInfo) {
    final clusterId = clusterInfo["clusterId"];
    if (clusterId == null) return;

    // Already in the list?
    final exists = discoveredClusters.any((c) => c["clusterId"] == clusterId);
    if (exists) return;

    // Even if I'm already joined to this cluster, keep it visible
    // Do NOT filter it out.
    discoveredClusters.add(clusterInfo);

    print("Cluster Found: $clusterInfo");
    setState(() {});
  }

  void _onClusterJoinedInitiatorSideHandler() async {
    await _loadConnectedDevicesInitiator();
    _removeConnectedFromAvailable();
    setState(() {});
  }

  void _onClusterJoinedJoinerSideHandler(String clusterId) async {
    print("Joined Cluster (Joiner Side): $clusterId");

    // Remove it from discovered list
    discoveredClusters.removeWhere((c) => c["clusterId"] == clusterId);

    final db = await DBService().database;
    final clusterMaps = await db.query(
      "clusters",
      where: "clusterId = ?",
      whereArgs: [clusterId],
    );

    if (clusterMaps.isNotEmpty) {
      final cluster = Cluster.fromMap(clusterMaps.first);

      // assign to joinedCluster
      joinedCluster = cluster;

      setState(() {});
    }
  }

  Future<void> _onClusterInfoSentHandler() async {
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

    setState(() {});
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

  void _onStatusChangeHandler() async {
    if (widget.mode == DashboardMode.initiator) {
      await _loadConnectedDevicesInitiator();
    } else if (widget.mode == DashboardMode.joiner) {
      await _onClusterInfoSentHandler();
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

  String formatLastSeen(int millis) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 10) return "Active just now";
    if (diff.inMinutes < 1) return "Active ${diff.inSeconds}s ago";
    if (diff.inHours < 1) return "Active ${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "Active ${diff.inHours}h ago";
    if (diff.inDays < 7) return "Active ${diff.inDays}d ago";

    // For anything older, show date
    return "last seen ${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}";
  }

  Future<List<Device>> fetchConnectedDevicesJoiner(
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

  // This method prints database contents for debugging purposes
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
        "  - ${c['name']} (ID: ${c['clusterId']}) owned by ${c['ownerUuid']})",
      );
    }

    print("\nCluster Members (${members.length}):");
    for (var m in members) {
      print("  - Device ${m['deviceUuid']} in Cluster ${m['clusterId']}");
    }
    print("========================\n");
  }

  // UI build function with connectedDevices section for initiator mode
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                leading: const Icon(Icons.wifi_tethering),
                title: Text("Your Cluster: ${currentCluster!.name}'s Network"),
                subtitle: Text("Cluster ID: ${currentCluster!.clusterId}"),
              ),
            ),

          if (widget.mode == DashboardMode.initiator) ...[
            const SizedBox(height: 20),

            Text(
              "Available Devices",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 0.5,
              ),
            ),
            if (availableDevices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    "No devices found",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              ...availableDevices.map(
                (d) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.smartphone),
                    title: Text(d.deviceName),
                    trailing: TextButton(
                      onPressed: () =>
                          //pass cl
                          beacon.inviteToCluster(
                            d.endpointId,
                            currentCluster!.clusterId,
                          ),
                      child: const Text("Invite"),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            Text(
              "Connected Devices",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 0.5,
              ),
            ),
            if (connectedDevices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    "No connected devices yet",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              ...connectedDevices.map(
                (d) => Card(
                  child: ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Base smartphone icon
                        Icon(
                          Icons.smartphone,
                          size: 40,
                          color: Colors.grey[700],
                        ),

                        // Connected indicator (green circle with signal icon)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: d.isOnline ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ), // optional border for contrast
                            ),
                            child: Icon(
                              Icons.wifi,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text("${d.deviceName}"),
                    subtitle: d.isOnline
                        ? Text("Online", style: TextStyle(color: Colors.green))
                        : Text(
                            formatLastSeen(d.lastSeen.millisecondsSinceEpoch),
                          ),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert),
                      onSelected: (value) => {
                        if (value == 'chat') {},
                        if (value == 'quick_message') {},
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'chat', child: Text('Chat')),
                        PopupMenuItem(
                          value: 'quick_message',
                          child: Text('Send Quick Message'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],

          if (widget.mode == DashboardMode.joiner) ...[
            const SizedBox(height: 20),

            Text(
              "Discovered Clusters",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 0.5,
              ),
            ),
            if (discoveredClusters.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    "No clusters found",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              ...discoveredClusters.map(
                (c) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.people),
                    title: Text("${c["clusterName"]}'s Network"),

                    trailing: TextButton(
                      onPressed: () => beacon.joinCluster(
                        c["endpointId"]!,
                        c["clusterId"]!,
                        c["clusterName"]!,
                      ),
                      child: const Text("Join"),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              "Joined Cluster",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 0.5,
              ),
            ),

            if (joinedCluster == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    "No connected cluster yet",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              Column(
                children: [
                  Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cluster header
                          Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 35,
                                    color: Colors.grey[700],
                                  ),
                                  Positioned(
                                    right: -4,
                                    top: -2,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.wifi,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "${joinedCluster!.name}'s Network",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              // Cluster-level actions
                              IconButton(
                                icon: Icon(
                                  Icons.campaign,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () => {},
                                tooltip: "Broadcast",
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.exit_to_app,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => {
                                  beacon.disconnectFromCluster(),
                                  setState(() {
                                    joinedCluster = null;
                                    connectedDevicesToCluster.clear();
                                  }),
                                },
                                tooltip: "Leave",
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          //horizontal separator
                          if (connectedDevicesToCluster.isNotEmpty)
                            Divider(height: 1, color: Colors.grey[300]),
                          SizedBox(height: 12),

                          // Connected devices list as normal ListTile with dividers
                          ListView.separated(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: connectedDevicesToCluster.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey[300]),
                            itemBuilder: (context, index) {
                              final d = connectedDevicesToCluster[index];
                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 0,
                                ),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.smartphone,
                                      size: 40,
                                      color: Colors.grey[700],
                                    ),
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: d.isOnline
                                              ? Colors.green
                                              : Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.wifi,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(d.deviceName),
                                subtitle: d.isOnline
                                    ? Text(
                                        "Online",
                                        style: TextStyle(color: Colors.green),
                                      )
                                    : Text(
                                        formatLastSeen(
                                          d.lastSeen.millisecondsSinceEpoch,
                                        ),
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                trailing: PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'chat') {
                                      // openChat(d);
                                    }
                                    if (value == 'quick_message') {
                                      // sendQuickMessage(d);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'chat',
                                      child: Text('Chat'),
                                    ),
                                    PopupMenuItem(
                                      value: 'quick_message',
                                      child: Text('Send Quick Message'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
