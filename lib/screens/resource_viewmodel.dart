import 'package:flutter/material.dart';
import 'package:sqflite/sql.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import '../models/resource.dart';
import '../services/db_service.dart';
import '../services/nearby_connections/nearby_connections.dart';

class ResourceViewModel extends ChangeNotifier {
  final _dbService = DBService();
  final _beacon = NearbyConnections();

  ResourceType _selectedTab = ResourceType.foodWater;
  ResourceType get selectedTab => _selectedTab;

  List<Resource>? _resources;
  List<Resource>? get resources => _resources;

  List<Device> _connectedDevices = [];
  List<Device> get connectedDevices => _connectedDevices;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ResourceViewModel() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    await _beacon.init();
    await refreshData();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    _resources = await _fetchResources();
    _connectedDevices = await _fetchConnectedDevices();

    _isLoading = false;
    notifyListeners();
  }

  void changeTab(ResourceType type) {
    _selectedTab = type;
    notifyListeners();
  }

  Future<List<Resource>> _fetchResources() async {
    final database = await _dbService.database;
    final List<Map<String, dynamic>> maps = await database.query('resources');
    debugPrint('Fetched ${maps.length} resources from database');
    return List.generate(maps.length, (i) => Resource.fromMap(maps[i]));
  }

  Future<List<Device>> _fetchConnectedDevices() async {
    final database = await _dbService.database;
    final String deviceUuid = await _beacon.uuid;

    final joined = await database.query(
      'cluster_members',
      columns: ['clusterId'],
      where: 'deviceUuid = ?',
      whereArgs: [deviceUuid],
    );

    if (joined.isEmpty) {
      return [];
    }

    final clusterId = joined.first['clusterId'] as String;

    final List<Map<String, dynamic>> maps = await database.query(
      'devices',
      where:
          'uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)',
      whereArgs: [clusterId],
    );

    debugPrint(
        'Fetched ${maps.length} connected devices for cluster $clusterId');

    return List.generate(maps.length, (i) => Device.fromMap(maps[i]));
  }

  Future<void> postResource(String name, String description) async {
    try {
      final database = await _dbService.database;
      String userUuid = _beacon.uuid;

      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.posted,
        resourceId: const Uuid().v4(),
        resourceType: _selectedTab,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );

      await database.insert(
        'resources',
        newResource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final device in _connectedDevices) {
        if (device.uuid == userUuid) continue;
        await _beacon.sendMessage(
          device.endpointId,
          'RESOURCES',
          {'resources': [newResource.toMap()]},
        );
      }
      await refreshData(); // Refresh list after posting
    } catch (e) {
      debugPrint('Error posting resource: $e');
    }
  }

  Future<void> requestResource(String name, String description) async {
    try {
      final database = await _dbService.database;
      String userUuid = _beacon.uuid;

      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.requested,
        resourceId: const Uuid().v4(),
        resourceType: _selectedTab,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );

      await database.insert(
        'resources',
        newResource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Note: You might want to broadcast requests as well.
      await refreshData(); // Refresh list after requesting
    } catch (e) {
      debugPrint('Error requesting resource: $e');
    }
  }
}
