// lib/view_models/dashboard_view_model.dart
import 'package:beacon_project/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/models/dashboard_mode.dart';
import 'package:beacon_project/repositories/chat_repository.dart';
import 'package:beacon_project/repositories/chat_message_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/screens/chat_page.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardMode mode;
  final DeviceRepository deviceRepository;
  final ClusterRepository clusterRepository;
  final ClusterMemberRepository clusterMemberRepository;
  final ChatRepository chatRepository;
  final ChatMessageRepository chatMessageRepository;

  late final NearbyConnectionsBase nearby;

  // Initiator state
  Cluster? currentCluster;
  List<Device> availableDevices = [];
  List<Device> connectedDevices = [];

  // Joiner state
  Cluster? joinedCluster;
  List<Map<String, dynamic>> discoveredClusters = [];
  List<Device> connectedDevicesToCluster = [];

  DashboardViewModel({
    required this.mode,
    required this.deviceRepository,
    required this.clusterRepository,
    required this.clusterMemberRepository,
    required this.chatRepository,
    required this.chatMessageRepository,
  }) {
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
    await nearby.init(
      deviceRepository,
      clusterRepository,
      clusterMemberRepository,
      chatRepository,
      chatMessageRepository,
    );
    await nearby.startCommunication();

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
    discoveredClusters = List<Map<String, dynamic>>.from(
      joiner.discoveredClusters,
    );

    _loadConnectedDevicesJoiner();
    notifyListeners();
  }

  // INITIATOR METHODS
  Future<void> _loadCurrentClusterInitiator() async {
    print("[DASHBOARD]: loading current cluster");
    final sp = await SharedPreferences.getInstance();
    final myUuid = sp.getString('device_uuid');

    if (myUuid != null) {
      currentCluster = await clusterRepository.getClusterByOwnerUuid(myUuid);
    }

    debugPrint(
      "[DASHBOARD]: current cluster loaded: ${currentCluster?.name ?? 'none'}",
    );

    notifyListeners();
  }

  Future<void> _loadConnectedDevicesInitiator() async {
    print("[DASHBOARD]: loading connected devices");
    if (currentCluster == null) return;

    // Ensure uuid is initialized
    if (nearby.uuid == null) {
      print('[DASHBOARD] Error: device uuid not initialized');
      return;
    }

    final members = await clusterMemberRepository.getMembersByClusterId(
      currentCluster!.clusterId,
    );

    final deviceUuids = members
        .where((m) => m.deviceUuid != nearby.uuid!)
        .map((m) => m.deviceUuid)
        .toList();

    if (deviceUuids.isEmpty) {
      connectedDevices = [];
    } else {
      connectedDevices = await deviceRepository.getDevicesByUuids(deviceUuids);
    }

    debugPrint(
      "[DASHBOARD]: connected devices loaded: ${connectedDevices.length}",
    );

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
    final sp = await SharedPreferences.getInstance();
    final myUuid = sp.getString('device_uuid');

    if (myUuid != null) {
      final memberships = await clusterMemberRepository.getMembersByDeviceUuid(
        myUuid,
      );

      if (memberships.isNotEmpty) {
        final clusterId = memberships.first.clusterId;
        joinedCluster = await clusterRepository.getClusterById(clusterId);
      }
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

    final members = await clusterMemberRepository.getMembersByClusterId(
      joinedCluster!.clusterId,
    );

    // Ensure uuid is initialized
    if (nearby.uuid == null) {
      print('[DASHBOARD] Error: device uuid not initialized');
      return;
    }

    final deviceUuids = members
        .where((m) => m.deviceUuid != nearby.uuid!)
        .map((m) => m.deviceUuid)
        .toList();

    if (deviceUuids.isEmpty) {
      connectedDevicesToCluster = [];
    } else {
      connectedDevicesToCluster = await deviceRepository.getDevicesByUuids(
        deviceUuids,
      );
    }

    notifyListeners();
  }

  Future<void> joinCluster(Map<String, dynamic> clusterInfo) async {
    print("[DASHBOARD]: joining cluster");
    final joiner = nearby as NearbyConnectionsJoiner;
    await joiner.joinCluster(
      clusterInfo["endpointId"] as String,
      clusterInfo["clusterId"] as String,
      clusterInfo["clusterName"] as String,
    );
  }

  Future<void> acceptInvite(String endpointId) async {
    print("[DASHBOARD]: accepting invite");
    final joiner = nearby as NearbyConnectionsJoiner;
    await joiner.acceptInvite(endpointId);

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
  Future<void> printDatabaseContents() async {
    final devices = await deviceRepository.getAllDevices();
    final clusters = await clusterRepository.getAllClusters();

    print("=== DATABASE CONTENTS ===");
    print("\nDevices (${devices.length}):");
    for (var d in devices) {
      print("  - ${d.deviceName} (UUID: ${d.uuid})");
      print("    Endpoint ID: ${d.endpointId}");
      print("    Status: ${d.status}");
      print("    In_Range: ${d.inRange}");
    }

    print("\nClusters (${clusters.length}):");
    for (var c in clusters) {
      print("  - ${c.name} (ID: ${c.clusterId}) owned by ${c.ownerUuid}");

      final members = await clusterMemberRepository.getMembersByClusterId(
        c.clusterId,
      );
      print("  Members: ${members.length}");
      for (var m in members) {
        print("    - Device ${m.deviceUuid}");
      }
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

  // Add to DashboardViewModel class
  Future<void> broadcastMessage(String messageText) async {
    if (messageText.trim().isEmpty) return;

    try {
      final messageId = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await nearby.broadcastChatMessage(
        messageId,
        'broadcast',
        messageText.trim(),
        timestamp,
      );

      print(
        '[DashboardViewModel] Broadcasted message to ${nearby.connectedEndpoints.length} devices',
      );
    } catch (e) {
      print('[DashboardViewModel] Error broadcasting message: $e');
    }
  }

  Future<void> sendQuickMessage(Device device, String messageText) async {
    try {
      final messageId = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Generate chat ID
      final myUuid = await _getDeviceUUID();
      final chatId = _generateChatId(myUuid, device.uuid);

      await nearby.sendChatMessage(
        device.endpointId,
        messageId,
        chatId,
        messageText,
        timestamp,
      );
      await chatMessageRepository.insertMessage(
        ChatMessage(
          id: messageId,
          chatId: chatId,
          senderUuid: myUuid,
          messageText: messageText,
          timestamp: timestamp,
        ),
      );

      print('[DashboardViewModel] Sent quick message to ${device.deviceName}');
    } catch (e) {
      print('[DashboardViewModel] Error sending quick message: $e');
    }
  }

  Future<String> _getDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_uuid') ?? '';
  }

  String _generateChatId(String uuid1, String uuid2) {
    List<String> uuids = [uuid1, uuid2];
    uuids.sort();
    return '${uuids[0]}_${uuids[1]}';
  }

  // In dashboard_page.dart or dashboard_view_model.dart
  void navigateToGroupChat(BuildContext context, String clusterId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatPage(clusterId: clusterId, isGroupChat: true, nearby: nearby),
      ),
    );
  }

  void navigateToPrivateChat(BuildContext context, String deviceUuid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          deviceUuid: deviceUuid,
          isGroupChat: false,
          nearby: nearby,
        ),
      ),
    );
  }

  @override
  void dispose() {
    nearby.removeListener(_onNearbyStateChanged);
    super.dispose();
  }
}
