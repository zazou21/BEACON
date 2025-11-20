import 'package:flutter/material.dart';
import 'dart:async';
import 'package:beacon_project/models/device.dart';
import 'chat_page.dart';
import 'package:beacon_project/services/beacon_connections.dart';
import 'package:beacon_project/services/db_service.dart';

enum DashboardMode { BROWSING, ADVERTISING }
// final dbService = DBService();

class DashboardPage extends StatefulWidget {
  final DashboardMode mode;
  final String currentDeviceName;

  const DashboardPage({
    super.key,
    required this.mode,
    required this.currentDeviceName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Device> devices = [];
  late BeaconConnections beacon;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    beacon = BeaconConnections();
    _initBeacon();
  }

  Future<void> _initBeacon() async {
    await beacon.init(widget.currentDeviceName);

    // Set callback to update UI when a new device is found
    beacon.onDeviceFound = (device) {
      _loadDevices();
    };

    if (widget.mode == DashboardMode.ADVERTISING) {
      await beacon.initiateCommunication();
    } else {
      await beacon.joinCommunication();
    }

    _loadDevices();
    refreshTimer = Timer.periodic(Duration(seconds: 5), (_) => _loadDevices());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    print("Loading devices from DB...");
    final db = await DBService().database;
    final maps = await db.query('devices');
    print("loaded ${maps.length} devices");
    setState(() {
      devices = maps.map((m) => Device.fromMap(m)).toList();
    });
  }

  String formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return "${diff.inHours}h ago";
  }

  Color statusColor(String status) {
    switch (status) {
      case "Connected":
        return Colors.green;
      case "Available":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _connectDevice(Device device) async {
    try {
      // Request connection
      await beacon.initiateCommunication();
      setState(() {
        device.status = "Connected";
        device.lastSeen = DateTime.now();
      });
      await _updateDevice(device);
    } catch (e) {
      // handle error
    }
  }

  void _disconnectDevice(Device device) async {
    beacon.stopAll(); // stops advertising/discovery & disconnects all endpoints
    setState(() {
      device.status = "Available";
      device.lastSeen = DateTime.now();
    });
    await _updateDevice(device);
    _loadDevices();
  }

  // Accept or decline an invitation via dialog
  void _showConnectionRequest(Device device) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Connection Request'),
        content: Text('${device.deviceName} wants to connect. Accept?'),
        actions: [
          TextButton(
            child: Text('Decline'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Accept'),
            onPressed: () {
              beacon.acceptConnection(device.endpointId, beacon.handlePayload);

              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _quickMessage(Device device) {
    List<String> messages = ["Are you ok?", "Do you need anything?"];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Send Quick Message to ${device.deviceName}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: messages
                .map(
                  (msg) => ListTile(
                    title: Text(msg),
                    onTap: () {
                      beacon.sendTo(device.endpointId, msg);
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  void _chat(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(macAddress: device.uuid),
      ),
    );
  }

  Future<void> _updateDevice(Device device) async {
    final db = await DBService().database;
    await db.update(
      'devices',
      device.toMap(),
      where: 'uuid = ?',
      whereArgs: [device.uuid],
    );
  }

  bool isConnected(Device device) {
    return beacon.connectedEndpoints.contains(device.endpointId);
  }

  Future<void> _refreshDevices() async {
    await Future.delayed(Duration(seconds: 1));
    await _loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    final connected = devices.where((d) => d.status == "Connected").toList();
    final available = devices.where((d) => d.status == "Available").toList();

    return Scaffold(
      appBar: AppBar(title: Text('Device Dashboard')),
      body: RefreshIndicator(
        onRefresh: _refreshDevices,
        child: ListView(
          children: [
            Center(child: Icon(Icons.wifi, size: 50, color: Colors.grey)),
            SizedBox(height: 10),
            Center(
              child: Text(
                'Nearby Devices',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),

            Padding(
              padding: EdgeInsets.only(left: 10),
              child: Text(
                'Connected Devices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...connected.map(
              (device) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor(device.status),
                  child: Icon(Icons.devices, color: Colors.white),
                ),
                title: Text(device.deviceName),
                subtitle: Text(
                  "Status: ${isConnected(device) ? 'Connected' : 'Available'}\nLast seen: ${formatLastSeen(device.lastSeen)}",
                ),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'chat') _chat(device);
                    if (value == 'quick') _quickMessage(device);
                    if (value == 'disconnect') _disconnectDevice(device);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'chat', child: Text('Chat')),
                    PopupMenuItem(value: 'quick', child: Text('Quick Message')),
                    PopupMenuItem(
                      value: 'disconnect',
                      child: Text('Disconnect'),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            Padding(
              padding: EdgeInsets.only(left: 10),
              child: Text(
                'Available Devices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            ...available.map(
              (device) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor(device.status),
                  child: Icon(Icons.devices, color: Colors.white),
                ),
                title: Text(device.deviceName),
                subtitle: Text(
                  "Status: ${device.status}\nLast seen: ${formatLastSeen(device.lastSeen)}",
                ),
                trailing: Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.link),
                ),
                onTap: () {
                  if (widget.mode == DashboardMode.BROWSING) {
                    // Browsers can accept/decline invites
                    _showConnectionRequest(device);
                  } else {
                    // Advertiser connects proactively
                    _connectDevice(device);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
