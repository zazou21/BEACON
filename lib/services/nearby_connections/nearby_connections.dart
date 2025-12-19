import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/models/cluster_member.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:beacon_project/services/nearby_connections/payload_strategy_factory.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'package:beacon_project/repositories/chat_repository.dart';
import 'package:beacon_project/repositories/chat_message_repository.dart';

part 'nearby_connection_initiator.dart';
part 'nearby_connection_joiner.dart';

class PendingConnection {
  final String remoteUuid;
  final String clusterId;
  PendingConnection(this.remoteUuid, this.clusterId);
}

class PendingInvite {
  final String joinerUuid;
  final String clusterId;
  PendingInvite(this.joinerUuid, this.clusterId);
}

abstract class NearbyConnectionsBase extends ChangeNotifier {
  static const STRATEGY = Strategy.P2P_CLUSTER;
  static const SERVICE_ID = "com.beacon.emergency";

  // Repositories (nullable to allow re-initialization for singletons)
  DeviceRepository? deviceRepository;
  ClusterRepository? clusterRepository;
  ClusterMemberRepository? clusterMemberRepository;
  ChatRepository? chatRepository;
  ChatMessageRepository? chatMessageRepository;

  // Shared state
  final Map<String, String> _activeConnections = {};
  final List<String> _connectedEndpoints = [];
  String? deviceName;
  String? uuid;

  // Getters for reactive state
  // Getters for reactive state
  List<String> get connectedEndpoints => (_connectedEndpoints);

  Map<String, String> get activeConnections => (_activeConnections);

  // Clear endpoints safely
  void clearConnectedEndpoints() {
    _connectedEndpoints.clear();
    notifyListeners();
  }

  // Clear active connections safely
  void clearActiveConnections() {
    _activeConnections.clear();
    notifyListeners();
  }

  // Clear EVERYTHING safely
  void clearAllConnections() {
    _connectedEndpoints.clear();
    _activeConnections.clear();
    notifyListeners();
  }

  Future<void> init(
    DeviceRepository deviceRepo,
    ClusterRepository clusterRepo,
    ClusterMemberRepository clusterMemberRepo,
    ChatRepository chatRepo,
    ChatMessageRepository chatMessageRepo,
  ) async {
    // Assign repositories (allow re-assignment for singleton reuse)
    deviceRepository = deviceRepo;
    clusterRepository = clusterRepo;
    clusterMemberRepository = clusterMemberRepo;
    chatRepository = chatRepo;
    chatMessageRepository = chatMessageRepo;

    // Initialize deviceName and uuid
    deviceName = await _getDeviceName();
    uuid = await _getDeviceUUID();

    // initialize the repositories and pass them to the factory
    PayloadStrategyFactory.initialize(
      this,
      deviceRepository!,
      clusterRepository!,
      clusterMemberRepository!,
      chatRepository!,
      chatMessageRepository!,
    );
  }

  Future<String> _getDeviceName() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.model;
    } catch (_) {
      return "unknown";
    }
  }

  Future<String> _getDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString('device_uuid');
    if (stored == null) {
      stored = const Uuid().v4();
      await prefs.setString('device_uuid', stored);
    }
    return stored;
  }

  Future<bool> requestNearbyPermissions() async {
    final List<Permission> permissions = [
      Permission.locationWhenInUse,
      Permission.bluetooth,
    ];
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      int sdkInt = info.version.sdkInt;
      if (sdkInt >= 31) {
        permissions.addAll([
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
        ]);
      }
      if (sdkInt >= 33) permissions.add(Permission.nearbyWifiDevices);
    }
    final statuses = await permissions.request();
    return statuses.values.every((s) => s.isGranted);
  }

  void onPayloadReceived(String endpointId, Payload payload) {
    print("[Nearby]: payload received from $endpointId");
    try {
      if (payload.type == PayloadType.BYTES && payload.bytes != null) {
        final raw = String.fromCharCodes(payload.bytes!);
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          print("[Nearby] invalid message shape");
          return;
        }
        final map = Map<String, dynamic>.from(decoded);
        final type = map["type"];
        final data = map["data"];
        if (type == null || data == null || data is! Map) {
          print("[Nearby] missing type/data");
          return;
        }
        final handler = PayloadStrategyFactory.getHandler(type);
        handler.handle(endpointId, Map<String, dynamic>.from(data));
      }
    } catch (e) {
      print("[Nearby] payload parse error: $e");
    }
  }

  Future<void> sendMessage(
    String endpointId,
    String type,
    Map<String, dynamic> data,
  ) async {
    print("[Nearby]: sending message to $endpointId");
    final payload = {"type": type, "data": data};
    final jsonBytes = utf8.encode(jsonEncode(payload));
    try {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(jsonBytes),
      );
    } catch (e) {
      print("[Nearby] sendMessage error: $e");
    }
  }

  void onPayloadUpdate(String endpointId, PayloadTransferUpdate update) {}

  /// Reset singleton state to allow re-initialization
  void resetState() {
    deviceRepository = null;
    clusterRepository = null;
    clusterMemberRepository = null;
    deviceName = null;
    uuid = null;
    _connectedEndpoints.clear();
    _activeConnections.clear();
  }

  Future<void> stopAll() async {
    debugPrint("[Nearby]: stopping all (base)");

    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      debugPrint('[Nearby] stopAll error: $e');
    }

    clearAllConnections();
  }

  // Send chat message to specific endpoint
  Future<void> sendChatMessage(
    String endpointId,
    String messageId,
    String chatId,
    String messageText,
    int timestamp,
  ) async {
    debugPrint("[Nearby]: sending chat message to $endpointId");
    await sendMessage(endpointId, "CHAT_MESSAGE", {
      "message_id": messageId,
      "chat_id": chatId,
      "sender_uuid": uuid,
      "message": messageText,
      "timestamp": timestamp,
    });
  }

  // Broadcast chat message to all connected endpoints
  Future<void> broadcastChatMessage(
    String messageId,
    String chatId,
    String messageText,
    int timestamp,
  ) async {
    final data = {
      "message_id": messageId,
      "chat_id": chatId,
      "sender_uuid": uuid,
      "message": messageText,
      "timestamp": timestamp,
    };

    for (String endpointId in _connectedEndpoints) {
      await sendMessage(endpointId, "CHAT_MESSAGE", data);
    }
  }

  Future<void> startCommunication();
  Future<void> stopAdvertising();
  Future<void> stopDiscovery();
}
