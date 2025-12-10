import 'package:flutter/foundation.dart';
import 'package:sqflite/sqlite_api.dart';
import 'dart:async';
import '../models/resource.dart';
import '../models/device.dart';
import '../services/db_service.dart';
import '../services/nearby_connections/nearby_connections.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ResourceViewModel extends ChangeNotifier {
  ResourceType selectedTab = ResourceType.foodWater;
  List<Resource> resources = [];
  List<Device> connectedDevices = [];
  String? clusterId;

  late SharedPreferences prefs;
  final DBService dbService = DBService();

  late NearbyConnectionsBase beacon;
  late StreamSubscription<List<Resource>> _resourceStreamSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ---------- INIT & LISTENER SETUP ----------

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      prefs = await SharedPreferences.getInstance();

      final modeStr = prefs.getString('dashboard_mode');
      final isInitiator = modeStr == 'initiator';

      beacon = isInitiator
          ? NearbyConnectionsInitiator()
          : NearbyConnectionsJoiner();

      beacon.addListener(_onBeaconStateChanged);

      await beacon.init();

      // Initial load from DB
      await _reloadFromDb();

      // Listen to resource updates from the model
      _resourceStreamSubscription =
          Resource.resourceUpdateStream.listen((updatedResources) {
        print('[ResourceViewModel] Resources updated from stream');
        resources = updatedResources;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error initializing ResourceViewModel: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onBeaconStateChanged() async {
    try {
      await _reloadFromDb();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing on beacon change: $e');
    }
  }

  Future<void> _reloadFromDb() async {
    resources = await fetchResources();
    connectedDevices = await fetchConnectedDevices();
  }

  @override
  void dispose() {
    // Clean up listeners
    beacon.removeListener(_onBeaconStateChanged);
    _resourceStreamSubscription.cancel();
    super.dispose();
  }

  // ---------- UI STATE ----------

  void changeTab(ResourceType newTab) {
    selectedTab = newTab;
    notifyListeners();
  }

  // ---------- DATA LOADING ----------

  Future<List<Resource>> fetchResources() async {
    final database = await dbService.database;
    final List<Map<String, dynamic>> maps = await database.query('resources');
    return List.generate(maps.length, (i) => Resource.fromMap(maps[i]));
  }

  Future<List<Device>> fetchConnectedDevices() async {
    final database = await dbService.database;
    final String deviceUuid = beacon.uuid;

    final joined = await database.query(
      'cluster_members',
      columns: ['clusterId'],
      where: 'deviceUuid = ?',
      whereArgs: [deviceUuid],
    );

    if (joined.isEmpty) return [];

    clusterId = joined.first['clusterId'] as String;

    final List<Map<String, dynamic>> maps = await database.query(
      'devices',
      where:
          'uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)',
      whereArgs: [clusterId],
    );

    return List.generate(maps.length, (i) => Device.fromMap(maps[i]));
  }

 

  Future<void> postResource(String name, String description) async {
    try {
      _isLoading = true;
      notifyListeners();

      final database = await dbService.database;
      final String userUuid = beacon.uuid;

      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.posted,
        resourceId: const Uuid().v4(),
        resourceType: selectedTab,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );

      await database.insert(
        'resources',
        newResource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Broadcast to others in cluster
      for (final device in connectedDevices) {
        if (device.uuid == userUuid) continue;
        await beacon.sendMessage(
          device.endpointId,
          'RESOURCES',
          {'resources': [newResource.toMap()]},
        );
      }

      await _reloadFromDb();
    } catch (e) {
      debugPrint('Error posting resource: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestResource(String name, String description) async {
    try {
      _isLoading = true;
      notifyListeners();

      final database = await dbService.database;
      final String userUuid = beacon.uuid;

      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.requested,
        resourceId: const Uuid().v4(),
        resourceType: selectedTab,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );

      await database.insert(
        'resources',
        newResource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final device in connectedDevices) {
        if (device.uuid == userUuid) continue;
        await beacon.sendMessage(
          device.endpointId,
          'RESOURCES',
          {'resources': [newResource.toMap()]},
        );
      }

      await _reloadFromDb();
    } catch (e) {
      debugPrint('Error requesting resource: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
