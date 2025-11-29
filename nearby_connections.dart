import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:beacon_project/services/nearby_connections/payload_strategy_factory.dart';

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

  Function(String message)? onTextReceived;
  Function(Uint8List bytes)? onImageReceived;

  void Function(String endpointId, String message)? onChatMessageReceived;
  void Function(String endpointId, Uint8List imageBytes)? onChatImageReceived;

  // Shared state
  final Map<String, String> _activeConnections = {};
  final List<String> _connectedEndpoints = [];

  late String deviceName;
  late String uuid;

  // Getters for reactive state
  List<String> get connectedEndpoints => List.unmodifiable(_connectedEndpoints);
  Map<String, String> get activeConnections =>
      Map.unmodifiable(_activeConnections);

  Future<void> init() async {
    deviceName = await _getDeviceName();
    uuid = await _getDeviceUUID();
    PayloadStrategyFactory.initialize(this);
    notifyListeners();
  }

  Future<String> _getDeviceName() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.model;
    } catch (_) {
      return "unknown";
    }
  }

  void broadcastMessage(String message) {
    final strategy = PayloadStrategyFactory.getHandler("BROADCAST");
    strategy.handle('', {
      "message": message,
      "timestamp": DateTime.now().toIso8601String(),
    });

    // Trigger local callback so UI updates
    if (onTextReceived != null) onTextReceived!(message);
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

  // Convenience wrappers for chat usage:
  Future<void> sendChatMessage(String endpointId, String text) async {
    final payload = {
      "type": "CHAT_MESSAGE",
      "data": {"text": text},
    };
    final jsonBytes = utf8.encode(jsonEncode(payload));
    try {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(jsonBytes),
      );
    } catch (e) {
      print("[Nearby] sendChatMessage error: $e");
    }
  }

  Future<void> sendChatImage(String endpointId, Uint8List bytes) async {
    // Option A: embed raw list of ints
    final payload = {
      "type": "CHAT_IMAGE",
      "data": {"bytes": bytes.toList()},
    };
    final jsonBytes = utf8.encode(jsonEncode(payload));
    try {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(jsonBytes),
      );
    } catch (e) {
      print("[Nearby] sendChatImage error: $e");
    }
  }

  Future<void> broadcastMessage(String type, Map<String, dynamic> data) async {
    for (final epId in _connectedEndpoints) {
      sendChatMessage(epId, jsonEncode({"type": type, "data": data}));
    }
  }

  void onPayloadUpdate(String endpointId, PayloadTransferUpdate update) {}

  Future<void> stopAll() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      print('[Nearby] stopAll error: $e');
    }

    _connectedEndpoints.clear();
    _activeConnections.clear();
    notifyListeners();
  }

  Future<void> startCommunication();
  Future<void> stopAdvertising();
  Future<void> stopDiscovery();
}
