import 'package:flutter/material.dart';
import 'dart:async';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> devices = [
    {
      'name': "Galaxy S24",
      'mac': "00:11:22:33:44:55",
      'status': "Connected",
      'lastSeen': DateTime.now().subtract(Duration(seconds: 5)),
    },
    {
      'name': "Pixel 8",
      'mac': "66:77:88:99:AA:BB",
      'status': "Available",
      'lastSeen': DateTime.now().subtract(Duration(minutes: 1)),
    },
    {
      'name': "OnePlus 12",
      'mac': "CC:DD:EE:FF:00:11",
      'status': "Unavailable",
      'lastSeen': DateTime.now().subtract(Duration(minutes: 5)),
    },
    {
      'name': "iPhone 15",
      'mac': "22:33:44:55:66:77",
      'status': "Available",
      'lastSeen': DateTime.now().subtract(Duration(seconds: 30)),
    },
    {
      'name': "Huawei P60",
      'mac': "88:99:AA:BB:CC:DD",
      'status': "Connected",
      'lastSeen': DateTime.now().subtract(Duration(seconds: 10)),
    },
  ];

  Future<void> _refreshDevices() async {
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      print('devices refreshed');
    });
  }

  String formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return "${diff.inHours}h ago";
  }

  void connectDevice(String mac) {
    setState(() {
      devices = devices.map((d) {
        if (d['mac'] == mac) {
          return {...d, 'status': 'Connected', 'lastSeen': DateTime.now()};
        }
        return d;
      }).toList();
    });
  }

  void chat(String mac) {
    print('Navigate to chat with $mac');
  }

  void quickMessage(String deviceName) {
    List<String> messages = ["Are you ok?", "Do you need anything?"];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Send Quick Message to $deviceName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: messages
                .map(
                  (msg) => ListTile(
                    title: Text(msg),
                    onTap: () {
                      print("Sent '$msg' to $deviceName");
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

  @override
  Widget build(BuildContext context) {
    final connected = devices.where((d) => d['status'] == "Connected").toList();
    final available = devices.where((d) => d['status'] == "Available").toList();

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

            //connected device
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
                  backgroundColor: statusColor(device['status']),
                  child: Icon(Icons.devices, color: Colors.white),
                ),
                title: Text(device['name']),
                subtitle: Text(
                  "Status: ${device['status']}\nLast seen: ${formatLastSeen(device['lastSeen'])}",
                ),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'chat') chat(device['mac']);
                    if (value == 'quick') quickMessage(device['name']);
                    if (value == 'disconnect') print('disconnected');
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

            // available devices
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
                  backgroundColor: statusColor(device['status']),
                  child: Icon(Icons.devices, color: Colors.white),
                ),
                title: Text(device['name']),
                subtitle: Text(
                  "Status: ${device['status']}\nLast seen: ${formatLastSeen(device['lastSeen'])}",
                ),
                trailing: Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.link),
                ),
                onTap: () => connectDevice(device['mac']),
              ),
            ),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> Korkor
