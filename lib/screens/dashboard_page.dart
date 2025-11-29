import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beacon_project/viewmodels/dashboard_view_model.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';

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
  late DashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    saveModeOnce(widget.mode);
    _viewModel = DashboardViewModel(mode: widget.mode);
    _viewModel.initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _viewModel.markOffline();
    } else if (state == AppLifecycleState.resumed) {
      _viewModel.markOnline();
    }
  }

  void _showInviteDialog() {
    final joiner = _viewModel.beacon as NearbyConnectionsJoiner;
    final info = joiner.pendingInviteInfo;
    final endpointId = joiner.pendingInviteEndpointId;

    if (info == null || endpointId == null) return;

    final parts = info.endpointName.split("|");
    if (parts.length < 2) return;

    final clusterId = parts[1];
    final clusterName = "Cluster $clusterId";

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Network Invitation"),
        content: Text("Do you want to join $clusterName?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _viewModel.rejectInvite();
            },
            child: const Text("Reject"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _viewModel.acceptInvite(endpointId);
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DashboardViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            TextButton(
              onPressed: () => _viewModel.printDatabaseContents(),
              child: const Text("Print DB"),
            ),
            TextButton(
              onPressed: () => _viewModel.stopAll(),
              child: const Text("Stop All"),
            ),
          ],
        ),
        body: Consumer<DashboardViewModel>(
          builder: (context, viewModel, child) {
            // Show invite dialog if pending
            if (widget.mode == DashboardMode.joiner) {
              final joiner = viewModel.beacon as NearbyConnectionsJoiner;
              if (joiner.pendingInviteInfo != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showInviteDialog();
                });
              }
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (viewModel.currentCluster != null)
                  _buildClusterCard(viewModel.currentCluster!),

                if (widget.mode == DashboardMode.initiator)
                  _buildInitiatorView(viewModel)
                else
                  _buildJoinerView(viewModel),
              ],
            );
          },
        ),
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

  Widget _buildInitiatorView(DashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader("Available Devices"),

        if (viewModel.availableDevices.isEmpty)
          _buildEmptyState("No devices found")
        else
          ...viewModel.availableDevices.map(
            (d) => _buildAvailableDeviceCard(d, viewModel),
          ),

        const SizedBox(height: 20),
        _buildSectionHeader("Connected Devices"),

        if (viewModel.connectedDevices.isEmpty)
          _buildEmptyState("No connected devices yet")
        else
          ...viewModel.connectedDevices.map(
            (d) => _buildConnectedDeviceCard(d, viewModel),
          ),
      ],
    );
  }

  Widget _buildJoinerView(DashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionHeader("Discovered Clusters"),

        if (viewModel.discoveredClusters.isEmpty)
          _buildEmptyState("No clusters found")
        else
          ...viewModel.discoveredClusters.map(
            (c) => _buildDiscoveredClusterCard(c, viewModel),
          ),

        const SizedBox(height: 20),
        _buildSectionHeader("Joined Cluster"),

        if (viewModel.joinedCluster == null)
          _buildEmptyState("No connected cluster yet")
        else
          _buildJoinedClusterCard(viewModel.joinedCluster!, viewModel),
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

  Widget _buildAvailableDeviceCard(
    Device device,
    DashboardViewModel viewModel,
  ) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.smartphone),
        title: Text(device.deviceName),
        trailing: TextButton(
          onPressed: () => viewModel.inviteToCluster(device),
          child: const Text("Invite"),
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceCard(
    Device device,
    DashboardViewModel viewModel,
  ) {
    return Card(
      child: ListTile(
        leading: _buildDeviceIcon(device.isOnline),
        title: Text(device.deviceName),
        subtitle: device.isOnline
            ? const Text("Online", style: TextStyle(color: Colors.green))
            : Text(
                viewModel.formatLastSeen(
                  device.lastSeen.millisecondsSinceEpoch,
                ),
              ),
        trailing: _buildDeviceMenu(),
      ),
    );
  }

  Widget _buildDiscoveredClusterCard(
    Map<String, String> clusterInfo,
    DashboardViewModel viewModel,
  ) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.people),
        title: Text("${clusterInfo["clusterName"]}'s Network"),
        trailing: TextButton(
          onPressed: () => viewModel.joinCluster(clusterInfo),
          child: const Text("Join"),
        ),
      ),
    );
  }

  Widget _buildJoinedClusterCard(
    Cluster cluster,
    DashboardViewModel viewModel,
  ) {
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
                  onPressed: () => viewModel.disconnectFromCluster(),
                  tooltip: "Leave",
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (viewModel.connectedDevicesToCluster.isNotEmpty)
              Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: viewModel.connectedDevicesToCluster.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey[300]),
              itemBuilder: (context, index) {
                final d = viewModel.connectedDevicesToCluster[index];
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
                          viewModel.formatLastSeen(
                            d.lastSeen.millisecondsSinceEpoch,
                          ),
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
