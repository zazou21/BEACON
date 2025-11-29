import 'package:flutter/foundation.dart';
import 'package:sqflite/sqlite_api.dart';
import '../models/resource.dart';
import '../models/device.dart';
import '../services/db_service.dart';
import '../services/nearby_connections/nearby_connections.dart';
import 'package:uuid/uuid.dart';

class ResourceViewModel extends ChangeNotifier {
  ResourceType selectedTab = ResourceType.foodWater;
  List<Resource> resources = [];
  List<Device> connectedDevices = [];
  String clusterId = '';

  final DBService dbService = DBService();
  final NearbyConnections beacon = NearbyConnections();
  
  bool _isLoading = false;  // Changed to non-final so we can update it
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();  // Notify UI that loading started

    try {
      await beacon.init();
      resources = await fetchResources();
      connectedDevices = await fetchConnectedDevices();
    } catch (e) {
      debugPrint('Error initializing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();  // Notify UI that loading finished
    }
  }

  void changeTab(ResourceType newTab) {
    selectedTab = newTab;
    notifyListeners();
  }

  Future<List<Resource>> fetchResources() async {
    final database = await dbService.database;
    final List<Map<String, dynamic>> maps = await database.query('resources');
    return List.generate(maps.length, (i) => Resource.fromMap(maps[i]));
  }

  Future<List<Device>> fetchConnectedDevices() async {
    final database = await dbService.database;
    final String deviceUuid = await beacon.uuid;
    final joined = await database.query('cluster_members',
      columns: ['clusterId'],
      where: 'deviceUuid = ?',
      whereArgs: [deviceUuid],
    );
    if (joined.isEmpty) return [];
    clusterId = joined.first['clusterId'] as String;
    final List<Map<String, dynamic>> maps = await database.query(
      'devices',
      where: 'uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)',
      whereArgs: [clusterId],
    );
    return List.generate(maps.length, (i) => Device.fromMap(maps[i]));
  }

  Future<void> postResource(String name, String description) async {
    try {
      _isLoading = true;
      notifyListeners();

      final database = await dbService.database;
      String userUuid = await beacon.uuid;
      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.posted,
        resourceId: const Uuid().v4(),
        resourceType: selectedTab,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );
      await database.insert('resources', newResource.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.replace);
      
      for (final device in connectedDevices) {
        if (device.uuid == userUuid) continue;
        await beacon.sendMessage(device.endpointId, 'RESOURCES', 
          {'resources': [newResource.toMap()]});
      }
      
      await init();
    } catch (e) {
      debugPrint('Error posting resource: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestResource(String name, String description) async {
    try {
      _isLoading = true;
      notifyListeners();

      final database = await dbService.database;
      String userUuid = await beacon.uuid;
      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.requested,
        resourceId: const Uuid().v4(),
        resourceType: selectedTab,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );
      await database.insert('resources', newResource.toMap(), 
        conflictAlgorithm: ConflictAlgorithm.replace);
      
      for (final device in connectedDevices) {
        if (device.uuid == userUuid) continue;
        await beacon.sendMessage(device.endpointId, 'RESOURCES', 
          {'resources': [newResource.toMap()]});
      }
      
      await init();
    } catch (e) {
      debugPrint('Error requesting resource: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
}
