import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:beacon_project/viewmodels/dashboard_view_model.dart';
import 'package:beacon_project/models/dashboard_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/services/nearby_connections/mode_change_notifier.dart';
import 'dart:async';

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

class _DashboardPageState extends State<DashboardPage> {
  late DashboardViewModel _viewModel;
  StreamSubscription<DashboardMode>? _modeChangeSubscription;
  late DashboardMode _currentMode;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
    saveModeOnce(widget.mode);
    _viewModel = DashboardViewModel(mode: _currentMode);
    _viewModel.initializeNearby();

    // Listen for mode changes
    _modeChangeSubscription = ModeChangeNotifier().modeChangeStream.listen((
      newMode,
    ) {
      if (newMode != _currentMode && !_isTransitioning) {
        _handleModeChange(newMode);
      }
    });
  }

  Future<void> _handleModeChange(DashboardMode newMode) async {
    if (_isTransitioning) return;

    setState(() => _isTransitioning = true);

    print('[Dashboard] 🔄 Mode change detected: $_currentMode -> $newMode');

    try {
      print('[Dashboard] Stopping old mode services...');
      await _viewModel.nearby.stopAdvertising();
      await _viewModel.nearby.stopDiscovery();

      // Add delay to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 800));

      _viewModel.nearby.removeListener(_viewModel.onNearbyStateChanged);

      setState(() {
        _currentMode = newMode;
      });

      print('[Dashboard] Creating new ViewModel for $newMode');
      _viewModel.dispose();

      _viewModel = DashboardViewModel(mode: newMode);

      print('[Dashboard] Initializing new nearby service...');
      await _viewModel.initializeNearby();

      print(
        '[Dashboard] Mode change complete - now ${newMode == DashboardMode.initiator ? "OWNER (advertising)" : "MEMBER"}',
      );

      // Show a notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'You are now the cluster owner!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('[Dashboard]: Error during mode change: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTransitioning = false);
      }
    }
  }

  @override
  void dispose() {
    _modeChangeSubscription?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _showInviteDialog() {
    if (_currentMode != DashboardMode.joiner) return;

    final joiner = _viewModel.nearby as NearbyConnectionsJoiner;
    final info = joiner.pendingInviteInfo;
    final endpointId = joiner.pendingInviteEndpointId;
    if (info == null || endpointId == null) return;

    final parts = info.endpointName.split("|");
    if (parts.length < 2) return;

    final clusterId = parts[1];
    // find the cluster name from discovered clusters
    final clusterName = _viewModel.discoveredClusters.firstWhere(
      (c) => c["clusterId"] == clusterId,
      orElse: () => {"clusterName": "Unknown"},
    )["clusterName"];




    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Network Invitation"),
        content: Text("Do you want to join cluster $clusterName?"),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _viewModel.rejectInvite();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reject", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _viewModel.acceptInvite(endpointId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("Join", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(bool isOnline) {
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

  Widget _clusterIcon() {
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

  Widget _popupMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {},
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'chat', child: Text('Chat')),
        PopupMenuItem(
          value: 'quick_message',
          child: Text('Send Quick Message'),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
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

  Future<void> _showDisconnectConfirmation(
    BuildContext context,
    DashboardViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Disconnect from Cluster'),
        content: Text(
          'You are the cluster owner. Ownership will be transferred to another '
          'member before you disconnect. You will be returned to the home screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true), // Return true
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Perform disconnect operations
    await viewModel.stopAll();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dashboard_mode');

    if (context.mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (_isTransitioning)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
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
            if (_currentMode == DashboardMode.joiner) {
              final joiner = viewModel.nearby as NearbyConnectionsJoiner;
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
                  Column(
                    children: [
                      Card(
                        elevation: 4,
                        child: ListTile(
                          leading: _clusterIcon(),
                          title: Text(
                            "Your Cluster: ${viewModel.currentCluster!.name}'s Network",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          //broadcast button
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.campaign),
                            label: const Text('Broadcast'),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          //disconnect button
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _showDisconnectConfirmation(
                                context,
                                viewModel,
                              );
                            },
                            icon: const Icon(Icons.exit_to_app),
                            label: Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,

                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                if (_currentMode == DashboardMode.initiator) ...[
                  _sectionHeader("Available Devices"),
                  if (viewModel.availableDevices.isEmpty)
                    _emptyState("No devices found")
                  else
                    ...viewModel.availableDevices.map(
                      (d) => Card(
                        child: InkWell(
                          onTap: () => viewModel.inviteToCluster(d),
                          child: ListTile(
                            leading: _statusIcon(d.isOnline),
                            title: Text(d.deviceName),
                            subtitle: d.isOnline
                                ? const Text(
                                    "Tap to invite",
                                    style: TextStyle(color: Colors.blue),
                                  )
                                : Text(
                                    viewModel.formatLastSeen(
                                      d.lastSeen.millisecondsSinceEpoch,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _sectionHeader("Connected Devices"),
                  if (viewModel.connectedDevices.isEmpty)
                    _emptyState("No connected devices yet")
                  else
                    ...viewModel.connectedDevices.map(
                      (d) => Card(
                        child: ListTile(
                          leading: _statusIcon(d.isOnline),
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
                                ),
                          trailing: _popupMenu(),
                        ),
                      ),
                    ),
                ],

                if (_currentMode == DashboardMode.joiner) ...[
                  _sectionHeader("Discovered Clusters"),
                  if (viewModel.discoveredClusters.isEmpty)
                    _emptyState("No clusters found")
                  else
                    ...viewModel.discoveredClusters.map(
                      (c) => Card(
                        child: InkWell(
                          onTap: () => viewModel.joinCluster(c),
                          child: ListTile(
                            leading: _clusterIcon(),
                            title: Text("${c["clusterName"]}'s Network"),
                            subtitle: const Text("Tap to join"),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _sectionHeader("Joined Cluster"),
                  if (viewModel.joinedCluster == null)
                    _emptyState("No connected cluster yet")
                  else
                    Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      elevation: 4,
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
                                _clusterIcon(),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "${viewModel.joinedCluster!.name}'s Network",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.campaign,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () {},
                                  tooltip: "Broadcast",
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.exit_to_app,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () =>
                                      viewModel.disconnectFromCluster(),
                                  tooltip: "Leave",
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (viewModel.connectedDevicesToCluster.isNotEmpty)
                              Divider(height: 1, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            if (viewModel.connectedDevicesToCluster.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    "No other members yet",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount:
                                    viewModel.connectedDevicesToCluster.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: Colors.grey[300]),
                                itemBuilder: (context, index) {
                                  final d = viewModel
                                      .connectedDevicesToCluster[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: _statusIcon(d.isOnline),
                                    title: Text(d.deviceName),
                                    subtitle: d.isOnline
                                        ? const Text(
                                            "Online",
                                            style: TextStyle(
                                              color: Colors.green,
                                            ),
                                          )
                                        : Text(
                                            viewModel.formatLastSeen(
                                              d.lastSeen.millisecondsSinceEpoch,
                                            ),
                                          ),
                                    trailing: _popupMenu(),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
