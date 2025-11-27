import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
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

// Helper small data classes for clarity
class PendingConnection {
  final String remoteUuid; // joiner or owner depending on flow
  final String clusterId;
  PendingConnection(this.remoteUuid, this.clusterId);
}

class PendingInvite {
  final String joinerUuid;
  final String clusterId;
  PendingInvite(this.joinerUuid, this.clusterId);
}

class NearbyConnections {
  static final NearbyConnections _instance = NearbyConnections._internal();
  factory NearbyConnections() => _instance;
  NearbyConnections._internal();

  static const STRATEGY = Strategy.P2P_CLUSTER;
  static const SERVICE_ID = "com.beacon.emergency";

  // ================= pending maps & state =================
  final Map<String, PendingConnection> _pendingConnections = {};
  final Map<String, PendingInvite> _pendingInvites = {};
  final Map<String, String> _activeConnections = {}; // endpointId -> deviceUuid
  final List<String> connectedEndpoints = [];
  final List<String> availableClusters = [];
  final List<String> availableDevices = [];

  // Device info
  late String deviceName;
  late String uuid;

  Cluster? createdCluster;
  Cluster? joinedCluster;


  void Function(Device device)? onDeviceFound;
  void Function(String endpointId, ConnectionInfo info)? onConnectionRequest;
  void Function(String endpointId, Map<String, dynamic> message)?
  onControlMessage;
  void Function(Map<String, String> cluster)? onClusterFound;
  void Function()? onClusterJoinedInitiatorSide;
  void Function(String clusterId)? onClusterJoinedJoinerSide;

  void Function()? onClusterInfoSent;
  void Function()? onStatusChange;

  Future<void> init() async {
    deviceName = await _getDeviceName();
    uuid = await _getDeviceUUID();
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

  Future<bool> _requestNearbyPermissions() async {
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

  // ================= INITIATOR FLOW =================
  // initiator device creates the cluster & adds himself
  // start discovering so he can see joiners he can invite
  // start advertising the cluster he created so joiners can find him
  Future<void> initiateCommunication() async {
    if (!await _requestNearbyPermissions()) return;

    //check if the user already created and is the owner and member of a cluster
    final db = await DBService().database;
    final existing = await db.query(
      "clusters",
      where: "ownerUuid = ?",
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      print('[Nearby] existing cluster found for initiator');
    } else {
      print('[Nearby] no existing cluster found for initiator');
      final clusterId = const Uuid().v4();
      final cluster = Cluster(
        clusterId: clusterId,
        ownerUuid: uuid,
        name: deviceName,
      );
      createdCluster = cluster;

      try {
        await db.transaction((txn) async {
          await txn.insert(
            'clusters',
            cluster.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await txn.insert('cluster_members', {
            'clusterId': clusterId,
            'deviceUuid': uuid,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        });
        await _startAdvertisingInitiator(clusterId, cluster.name);
        await _startDiscoveryInitiator();
      } catch (e) {
        print('[Nearby] DB error while creating cluster: $e');
      }
    }
  }

  // advertise the created cluster

  Future<void> _startAdvertisingInitiator(
    String clusterId,
    String clusterName,
  ) async {
    final endpointName =
        "ac|$uuid|$clusterId|$clusterName"; // format: <type>|<ownerUuid>|<clusterId>|<clusterName>
    // to be discovered by joiners (_onClusterFound)
    try {
      await Nearby().startAdvertising(
        endpointName,
        STRATEGY,
        serviceId: SERVICE_ID,
        onConnectionInitiated:
            _onConnectionInitiatedInitiator, // triggerd by JoinCluster
        onConnectionResult: _onConnectionResultInitiatorSide,
        onDisconnected: _onDisconnectedInitiatorSide,
      );
    } catch (e) {
      print('[Nearby] startAdvertising initiator error: $e');
    }
  }

  //  triggered by JoinCluster
  void _onConnectionInitiatedInitiator(
    String endpointId,
    ConnectionInfo info,
  ) async {
    try {
      print('[Nearby] connection initiatedd: $endpointId');
      final parts = info.endpointName.split('|'); // <joinerUuid>|<clusterId>
      // triggered by joinCluster
      if (parts.length < 2) {
        print(
          '[Nearby] initiator: bad endpointName format: ${info.endpointName}',
        );
        return;
      }
      final joinerUuid = parts[0];
      final clusterId = parts[1];

      // store for onConnectionResult
      _pendingConnections[endpointId] = PendingConnection(
        joinerUuid,
        clusterId,
      );

      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadUpdate,
      );
    } catch (e, st) {
      print('[Nearby] _onConnectionInitiatedInitiator error: $e\n$st');
      _pendingConnections.remove(endpointId);
    }
  }

  void _onConnectionResultInitiatorSide(
    String endpointId,
    Status status,
  ) async {
    if (status != Status.CONNECTED) {
      _pendingConnections.remove(endpointId); // cleanup
      return;
    }

    final data = _pendingConnections.remove(endpointId);
    if (data == null) return;

    final joinerUuid = data.remoteUuid;
    final clusterId = data.clusterId;

    try {
      final db = await DBService().database;
      await db.transaction((txn) async {
        await txn.update(
          "devices",
          {"status": "Connected", "lastSeen": DateTime.now().toIso8601String()},
          where: "uuid = ?",
          whereArgs: [joinerUuid],
        );

        await txn.insert("cluster_members", {
          "clusterId": clusterId,
          "deviceUuid": joinerUuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });

      _activeConnections[endpointId] = joinerUuid;
      if (!connectedEndpoints.contains(endpointId))
        connectedEndpoints.add(endpointId);

      // 1. update ui
      onClusterJoinedInitiatorSide?.call();

      // //2. query devices from device tables in cluster
      final devices_in_cluster = await db.query(
        "devices",
        where:
            "uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)",
        whereArgs: [clusterId],
      );

      // //3. query cluster members from cluster_members table
      final cluster_members = await db.query(
        "cluster_members",
        where: "clusterId = ?",
        whereArgs: [clusterId],
      );

      // 4. create device for myself
      final selfDevice = Device(
        uuid: uuid,
        deviceName: deviceName,
        endpointId: '',
        status: "Connected",
        lastSeen: DateTime.now(),
      );

      final devicesList = List<Map<String, dynamic>>.from(devices_in_cluster);
      devicesList.add(selfDevice.toMap());

      // send cluster info to all cluster members endpoint loop

      for (final epId in connectedEndpoints) {
        final pending = _activeConnections[epId];
        if (pending == null) continue;

        final isMember = await db.query(
          "cluster_members",
          where: "clusterId = ? AND deviceUuid = ?",
          whereArgs: [clusterId, pending],
          limit: 1,
        );

        if (isMember.isEmpty) continue;

        sendMessage(epId, "CLUSTER_INFO", {
          "clusterId": clusterId,
          "senderUuid": uuid,
          "devices": devicesList,
          "members": cluster_members,
        });
      }

      print("Initiator connected to joiner $joinerUuid");
    } catch (e) {
      print('[Nearby] _onConnectionResultInitiatorSide db error: $e');
    }
  }

  // joiner presses join on discovered cluster
  // this fn is called from UI
  // will trigger onConnectionInitiated on initiator side
  Future<void> joinCluster(
    String endpointId,
    String clusterId,
    String clusterName,
  ) async {
    final nameToSend = "$uuid|$clusterId"; // format expected by initiator
    try {
      await Nearby().requestConnection(
        // will trigger _onConnectionInitiatedInitiator
        nameToSend,
        endpointId,
        onConnectionInitiated: (id, info) async {
          print('joiner accepted connection initiation');
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: _onPayloadReceived,
            onPayloadTransferUpdate: _onPayloadUpdate,
          );
        },
        onConnectionResult: (id, status) async {
          print("Joiner result: $status");
          if (status != Status.CONNECTED) return;

          final db = await DBService().database;

          try {
            // get cluster info from db using id
            final cluster = await db.query(
              "clusters",
              where: "clusterId = ?",
              whereArgs: [clusterId],
              limit: 1,
            );
            if (cluster.isNotEmpty) {
              joinedCluster = Cluster.fromMap(cluster.first);
            }
            // insert self as member
            db.insert("cluster_members", {
              "clusterId": clusterId,
              "deviceUuid": uuid,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          } catch (e) {
            print('[Nearby] joinCluster DB error: $e');
          }

          _activeConnections[id] = joinedCluster!.ownerUuid;
          if (!connectedEndpoints.contains(id)) connectedEndpoints.add(id);

          onClusterJoinedJoinerSide?.call(clusterId);
        },
        onDisconnected: (id) {
          print("Joiner disconnected: $id");
          final db = DBService().database;
          final devUuid = _activeConnections.remove(id);
          connectedEndpoints.remove(id);
          joinedCluster= null;
          // remove self from cluster members in db
          db.then((database) => database.delete(
                "cluster_members",
                where: "deviceUuid = ?",
                whereArgs: [uuid],
              ));

        },
      );
    } catch (e) {
      print("[Nearby] requestConnection error: $e");
    }
  }

  void _onDisconnectedInitiatorSide(String endpointId) async {
    print("[Nearby] Initiator side disconnected: $endpointId");
    final devUuid = _activeConnections.remove(endpointId);
    connectedEndpoints.remove(endpointId);
    if (devUuid == null) return;
    try {
      final db = await DBService().database;
      await db.update(
        "devices",
        {
          "status": "Disconnected",
          "lastSeen": DateTime.now().toIso8601String(),
        },
        where: "uuid = ?",
        whereArgs: [devUuid],
      );
      // remove as cluster member from db
      await db.delete(
        "cluster_members",
        where: "deviceUuid = ?",
        whereArgs: [devUuid],
      );
      // notify ui
      onClusterJoinedInitiatorSide?.call();
    } catch (e) {
      print('[Nearby] disconnect cleanup error: $e');
    }
  }

  // user pressed disconnect button
  // this function called from ui
  // will trigger onDisconnected callbacks from initiator side
  Future<void> disconnectFromCluster() async {
    print('[Nearby] disconnecting from cluster');
    //find endpoint of cluster owner
    for (final endpointId in connectedEndpoints) {
      final devUuid = _activeConnections[endpointId];
      print('[Nearby] checking endpoint $endpointId with devUuid $devUuid');
      if (devUuid == null) continue;
      if (devUuid == joinedCluster!.ownerUuid) {
        await Nearby().disconnectFromEndpoint(endpointId);
      }
    }
  }

  // start discovering available devices so he can invite them to join his cluster
  Future<void> _startDiscoveryInitiator() async {
    try {
      await Nearby().startDiscovery(
        deviceName,
        STRATEGY,
        serviceId: SERVICE_ID,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
    } catch (e) {
      print('[Nearby] startDiscovery initiator error: $e');
    }
  }

  // when a device is found during discovery
  // save it to database and notify UI to update available devices list
  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    print('[Nearby] endpoint foundd: $endpointId');
    final parts = endpointName.split('|'); // format: <type>|<devUuid>|<name>
    // received from _startAdvertisingJoiner
    if (parts.length < 3) return;
    final type = parts[0];
    if (type != 'as') return; // only accept advertising joiner
    final devUuid = parts[1];
    final name = parts[2];

    final device = Device(
      uuid: devUuid,
      deviceName: name,
      endpointId: endpointId,
      status: "Available",
      lastSeen: DateTime.now(),
    );

    try {
      final db = await DBService().database;

      // Check if device already exists
      final existing = await db.query(
        "devices",
        where: "uuid = ?",
        whereArgs: [devUuid],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final currentStatus = existing.first["status"] as String?;

        // If device is connected or any other non-"Available" state, do NOT overwrite
        if (currentStatus != null && currentStatus != "Available") {
          return;
        }
      }

      // Only insert/replace if new or currently "Available"
      await db.insert(
        "devices",
        device.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('[Nearby] insert device error: $e');
    }

    onDeviceFound?.call(device);
  }

  void _onEndpointLost(String? endpointId) async {
    // optional: mark device as lost in DB
  }

  // ================= JOINER FLOW =================
  // joiner device looks for available clusters to join
  // start advertising so initiator can find him and invite him
  Future<void> joinCommunication() async {
    if (!await _requestNearbyPermissions()) return;
    //check if the user is already a member of a cluster
    final db = await DBService().database;
    final existing = await db.query(
      "cluster_members",
      where: "deviceUuid = ?",
      whereArgs: [uuid],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      print('[Nearby] existing cluster membership found for joiner');
      return;
    }
    print('[Nearby] no existing cluster membership found for joiner');
    await _startAdvertisingJoiner();
    await _startDiscoveryJoiner();
  }

  // advertise self so initiator can find him and invite him
  Future<void> _startAdvertisingJoiner() async {
    final endpointName = "as|$uuid|$deviceName"; // <type>|<uuid>|<name>
    // to be discovered by initiator (_onEndpointFound)

    try {
      await Nearby().startAdvertising(
        endpointName,
        STRATEGY,
        serviceId: SERVICE_ID,
        onConnectionInitiated:
            _onConnectionInitiatedJoiner, // trigger by request connection (InviteTOCluster)
        onConnectionResult: _onConnectionResultJoiner,
        onDisconnected: _onDisconnectedJoiner,
      );
    } catch (e) {
      print('[Nearby] startAdvertising joiner error: $e');
    }
  }

  void _onConnectionInitiatedJoiner(String endpointId, ConnectionInfo info) {
    final parts = info.endpointName.split('|'); // <ownerUuid>|<clusterId>
    if (parts.length < 2) {
      print('[Nearby] joiner: bad endpoint name: ${info.endpointName}');
      return;
    }
    final ownerUuid = parts[0];
    final clusterId = parts[1];

    _pendingConnections[endpointId] = PendingConnection(ownerUuid, clusterId);

    print('Invite dialog shown');

    // info.endpointName contains <initiatorUuid>|<clusterId>
    onConnectionRequest?.call(endpointId, info); // show invite dialog
  }

  // called from ui when joiner accepts the invite
  Future<void> acceptInvite(String endpointId) async {
    try {
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadUpdate,
      );
    } catch (e) {
      print('[Nearby] acceptInvite error: $e');
    }
  }

  void _onConnectionResultJoiner(String endpointId, Status status) async {
    print("Joiner result: $status");

    if (status != Status.CONNECTED) return;

    final data = _pendingConnections.remove(endpointId);
    if (data == null) return;
    final ownerUuid = data.remoteUuid;
    final clusterId = data.clusterId;

    try {
      final db = await DBService().database;
      await db.transaction((txn) async {
        await txn.insert(
          "clusters",
          Cluster(
            clusterId: clusterId,
            ownerUuid: ownerUuid,
            name: "Joined Cluster",
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.insert("cluster_members", {
          "clusterId": clusterId,
          "deviceUuid": uuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });

      _activeConnections[endpointId] = ownerUuid;
      if (!connectedEndpoints.contains(endpointId))
        connectedEndpoints.add(endpointId);

      onClusterJoinedJoinerSide?.call(clusterId);

      print("Joiner connected to initiator $ownerUuid");
    } catch (e) {
      print('[Nearby] _onConnectionResultJoiner db error: $e');
    }
  }

  void _onDisconnectedJoiner(String endpointId) async {
    print("Joiner disconnected: $endpointId");
    final devUuid = _activeConnections.remove(endpointId);
    connectedEndpoints.remove(endpointId);
    if (devUuid == null) return;
    try {
      final db = await DBService().database;
      await db.update(
        "devices",
        {
          "status": "Disconnected",
          "lastSeen": DateTime.now().toIso8601String(),
        },
        where: "uuid = ?",
        whereArgs: [devUuid],
      );
    } catch (e) {
      print('[Nearby] joiner disconnect cleanup error: $e');
    }
  }

  Future<void> inviteToCluster(String endpointId, String clusterId) async {
    final name = "$uuid|$clusterId"; // initiatorUuid|clusterId
    print('inviting to cluster');

    // store clusterId in pending invites BEFORE requesting connection so it's available later
    _pendingInvites[endpointId] = PendingInvite('', clusterId);

    try {
      await Nearby().requestConnection(
        name,
        endpointId,
        onConnectionInitiated:
            _onConnectionInitiatedInitiatorSideOfInvite, // will trigger
        onConnectionResult: _onConnectionResultInitiatorSideOfInvite,
        onDisconnected: _onDisconnectedInitiatorSideOfInvite,
      );
    } catch (e) {
      print('[Nearby] inviteToCluster error: $e');
      _pendingInvites.remove(endpointId);
    }
  }

  void _onConnectionInitiatedInitiatorSideOfInvite(
    String endpointId,
    ConnectionInfo info,
  ) async {
    try {
      final parts = info.endpointName.split(
        '|',
      ); // format type|<joinerUuid>|<clusterId>
      if (parts.isEmpty) return;
      final type = parts[0];

      final joinerUuid = parts[1];

      final existing = _pendingInvites[endpointId];
      final clusterId = existing?.clusterId ?? '';

      _pendingInvites[endpointId] = PendingInvite(joinerUuid, clusterId);

      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadUpdate,
      );
    } catch (e) {
      print('[Nearby] _onConnectionInitiatedInitiatorSideOfInvite error: $e');
      _pendingInvites.remove(endpointId);
    }
  }

  void _onConnectionResultInitiatorSideOfInvite(
    String endpointId,
    Status status,
  ) async {
    if (status != Status.CONNECTED) {
      _pendingInvites.remove(endpointId);
      return;
    }

    final data = _pendingInvites.remove(endpointId);
    if (data == null) return;

    final joinerUuid = data.joinerUuid; //dah 3'alat

    final clusterId = data.clusterId;

    print(clusterId);

    try {
      final db = await DBService().database;
      await db.transaction((txn) async {
        await txn.update(
          "devices",
          {"status": "Connected", "lastSeen": DateTime.now().toIso8601String()},
          where: "uuid = ?",
          whereArgs: [joinerUuid],
        );

        await txn.insert("cluster_members", {
          "clusterId": clusterId,
          "deviceUuid": joinerUuid,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });

      _activeConnections[endpointId] = joinerUuid;
      if (!connectedEndpoints.contains(endpointId))
        connectedEndpoints.add(endpointId);

      onClusterJoinedInitiatorSide?.call();

      final devices_in_cluster = await db.query(
        "devices",
        where:
            "uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)",
        whereArgs: [clusterId],
      );

      // //3. query cluster members from cluster_members table
      final cluster_members = await db.query(
        "cluster_members",
        where: "clusterId = ?",
        whereArgs: [clusterId],
      );

      // 4. create device for myself
      final selfDevice = Device(
        uuid: uuid,
        deviceName: deviceName,
        endpointId: '',
        status: "Connected",
        lastSeen: DateTime.now(),
      );

      final devicesList = List<Map<String, dynamic>>.from(devices_in_cluster);
      devicesList.add(selfDevice.toMap());

      //5. send
      sendMessage(endpointId, "CLUSTER_INFO", {
        "clusterId": clusterId,
        "senderUuid": uuid,
        "devices": devicesList,
        "members": cluster_members,
      });

      print('[Nearby] Joiner $joinerUuid added to cluster $clusterId');
    } catch (e) {
      print('[Nearby] _onConnectionResultInitiatorSideOfInvite db error: $e');
    }
  }

  void _onDisconnectedInitiatorSideOfInvite(String endpointId) async {
    print("Initiator side disconnected: $endpointId");

    final devUuid = _activeConnections.remove(endpointId);
    connectedEndpoints.remove(endpointId);
    if (devUuid == null) return;

    try {
      final db = await DBService().database;
      await db.update(
        "devices",
        {
          "status": "Disconnected",
          "lastSeen": DateTime.now().toIso8601String(),
        },
        where: "uuid = ?",
        whereArgs: [devUuid],
      );
    } catch (e) {
      print('[Nearby] disconnect cleanup error: $e');
    }
  }

  Future<void> _startDiscoveryJoiner() async {
    try {
      await Nearby().startDiscovery(
        deviceName,
        STRATEGY,
        serviceId: SERVICE_ID,
        onEndpointFound: _onClusterFound,
        onEndpointLost: _onClusterLost,
      );
    } catch (e) {
      print('[Nearby] startDiscovery joiner error: $e');
    }
  }

  void _onClusterFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    final parts = endpointName.split(
      '|',
    ); // type|<ownerUuid>|<clusterId>|<clusterName>
    // received from _startAdvertisingInitiator
    if (parts.length < 2) return;
    final clusterType = parts[0];
    if (clusterType != 'ac') return; // only accept advertising cluster

    final ownerUuid = parts[1];
    final clusterId = parts[2];
    final clusterName = parts[3];

    try {
      final db = await DBService().database;

      await db.insert(
        "clusters",
        Cluster(
          clusterId: clusterId,
          ownerUuid: ownerUuid,
          name: clusterName,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print('[Nearby] insert cluster error: $e');
    }

    onClusterFound?.call({
      "endpointId": endpointId,
      "clusterId": clusterId,
      "clusterName": clusterName,
    });
  }

  void _onClusterLost(String? endpointId) {}

  void _onPayloadReceived(String endpointId, Payload payload) {
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

        return;
      }

      print("[Nearby] unsupported payload type");
    } catch (e) {
      print("[Nearby] payload parse error: $e");
    }
  }

  Future<void> sendMessage(
    String endpointId,
    String type,
    Map<String, dynamic> data,
  ) async {
    final payload = {"type": type, "data": data};

    final jsonBytes = utf8.encode(jsonEncode(payload));
    try {
      print("[Nearby] sending message of type $type to $endpointId");
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(jsonBytes),
      );
    } catch (e) {
      print("[Nearby] sendMessage error: $e");
    }
  }

  void _onPayloadUpdate(String endpointId, PayloadTransferUpdate update) {}

  // ================= STOP =================
  Future<void> stopAll() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      print('[Nearby] stopAll error: $e');
    }

    connectedEndpoints.clear();
    _pendingConnections.clear();
    _pendingInvites.clear();
    _activeConnections.clear();
  }

  void markOffline() {
    for (var endpointId in connectedEndpoints) {
      sendMessage(endpointId, "MARK_OFFLINE", {"uuid": uuid});
    }
  }

  void markOnline() {
    for (var endpointId in connectedEndpoints) {
      sendMessage(endpointId, "MARK_ONLINE", {"uuid": uuid});
    }
  }

  void stopAdvertising() async {
    try {
      await Nearby().stopAdvertising();
    } catch (e) {
      print('[Nearby] stopAdvertising error: $e');
    }
  }

  void stopDiscovery() async {
    try {
      await Nearby().stopDiscovery();
    } catch (e) {
      print('[Nearby] stopDiscovery error: $e');
    }
  }
}
