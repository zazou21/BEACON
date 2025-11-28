import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
 
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class BeaconConnections {
  // singleton
  static final BeaconConnections _instance = BeaconConnections._internal();
  factory BeaconConnections() => _instance;
  BeaconConnections._internal();

  static const STRATEGY = Strategy.P2P_CLUSTER;
  static const SERVICE_ID = "com.beacon.emergency";

  final List<String> connectedEndpoints = [];
  String deviceName = "unknown";
  late String uuid;

  // Callback to notify UI about new devices
  void Function(Device device)? onDeviceFound;

  Future<void> init(String name) async {
    deviceName = name;
    uuid = await getDeviceUUID();
  }

  // hal maynfa3sh ne3mel da mac address?
  Future<String> getDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString('device_uuid');

    if (uuid == null) {
      uuid = const Uuid().v4();
      await prefs.setString('device_uuid', uuid);
    }

    return uuid;
  }

  /// Ask for all permissions needed by Nearby (location + bluetooth).


Future<bool> _requestNearbyPermissions() async {
  final List<Permission> permissions = [
    Permission.locationWhenInUse,
    Permission.bluetooth,
  ];

  int sdkInt = 0;

  // Get Android version safely
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    sdkInt = info.version.sdkInt;
  }

  // Android 12+ (API 31+)
  if (sdkInt >= 31) {
    permissions.addAll([
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ]);
  }

  // Android 13+ (API 33+)
  if (sdkInt >= 33) {
    permissions.add(Permission.nearbyWifiDevices);
  }

  // Request only supported permissions
  final statuses = await permissions.request();

  print("----------- PERMISSION CHECK -----------");
  print("Android SDK Detected: $sdkInt");

  statuses.forEach((perm, status) {
    print("$perm => $status");
  });

  print("----------------------------------------");

  final allGranted = statuses.values.every((s) => s.isGranted);
  return allGranted;
}


  Future<void> initiateCommunication() async {
    // Ensure permissions before advertising + discovery
    final granted = await _requestNearbyPermissions();
    if (!granted) {
      print("Nearby permissions not granted, aborting initiateCommunication");
      return;
    }

    await _startAdvertising();
    await _startDiscovery();
  }

  // eh el far2?
  Future<void> joinCommunication() async {
    final granted = await _requestNearbyPermissions();
    if (!granted) {
      print("Nearby permissions not granted, aborting joinCommunication");
      return;
    }

    await _startDiscovery();
    await _startAdvertising();
  }

  Future<void> _startAdvertising() async {
    try {
      await Nearby().startAdvertising(
        deviceName,
        STRATEGY,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: SERVICE_ID,
      );
    } catch (e) {
      print("Error in startAdvertising: $e");
    }
  }

  Future<void> _startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        deviceName,
        STRATEGY,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: SERVICE_ID,
      );
    } catch (e) {
      print("Error in startDiscovery: $e");
    }
  }

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    // Create a Device object for this endpoint
    final device = Device(
      uuid: '',
      deviceName: endpointName,
      endpointId: endpointId,
      status: "Available",
    );

    // Save to database
    final db = await DBService().database;
    try{
    await db.insert(
      'devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    } catch (e) {
      print("Error inserting device into DB: $e");
    }

    // Notify UI
    if (onDeviceFound != null) onDeviceFound!(device);

    // Request connection
    Nearby().requestConnection(
      deviceName,
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId != null) connectedEndpoints.remove(endpointId);
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) => _onPayloadReceived(id, payload),
    );

    // send our UUID immediately after connecting
    Nearby().sendBytesPayload(endpointId, Uint8List.fromList(uuid.codeUnits));
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED &&
        !connectedEndpoints.contains(endpointId)) {
      connectedEndpoints.add(endpointId);
    }
  }

  void _onDisconnected(String endpointId) {
    connectedEndpoints.remove(endpointId);
  }

  // el 7eta di hasesha ghareeba
  // el condition metbasmag awi efred 7ad ba3at message 3adeya nafs el format beta3 el UUID
  // we hal el message el 3adeya di hatethandel ezay ba3d keda
  // implement as middleware?

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES) {
      final message = String.fromCharCodes(payload.bytes!);

      // crude UUID check
      if (message.contains('-') && message.length == 36) {
        // Treat as peer UUID
        final db = await DBService().database;

        final existing = await db.query(
          'devices',
          where: 'uuid = ?',
          whereArgs: [message],
        );

        Device device;
        if (existing.isNotEmpty) {
          device = Device.fromMap(existing.first);
          device.endpointId = endpointId;
          device.lastSeen = DateTime.now();
        } else {
          device = Device(
            uuid: message,
            deviceName: 'Unknown',
            endpointId: endpointId,
            status: 'Available',
          );
        }

        await db.insert(
          'devices',
          device.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        // Regular message
        print("Message from $endpointId: $message");
      }
    }
  }

  Future<void> acceptConnection(
    String endpointId,
    void Function(String, Payload) onPayloadReceived,
  ) async {
    await Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: onPayloadReceived,
    );
  }

  void sendTo(String endpointId, String message) {
    Nearby().sendBytesPayload(
      endpointId,
      Uint8List.fromList(message.codeUnits),
    );
  }

  void broadcast(String message) {
    for (final id in connectedEndpoints) {
      sendTo(id, message);
    }
  }

  void handlePayload(String endpointId, Payload payload) {
    _onPayloadReceived(endpointId, payload);
  }

  Future<void> stopAll() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      connectedEndpoints.clear();
    } catch (e) {
      print("Error stopping Nearby: $e");
    }
  }
}
