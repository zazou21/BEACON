import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/resource.dart';
import '../models/device.dart';
import '../services/db_service.dart';
import '../services/nearby_connections/nearby_connections.dart';
import '../repositories/resource_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beacon_project/repositories/device_repository_impl.dart';
import 'package:beacon_project/repositories/cluster_repository_impl.dart';
import 'package:beacon_project/repositories/cluster_member_repository_impl.dart';
import 'package:beacon_project/repositories/chat_repository_impl.dart';
import 'package:beacon_project/repositories/chat_message_repository_impl.dart';

class ResourceViewModel extends ChangeNotifier {
  ResourceViewModel({
    ResourceRepository? repository,
    DBService? dbService,
    NearbyConnectionsBase? nearbyConnections,
  }) : _providedRepository = repository,
       _dbService = dbService ?? DBService(),
       beacon = nearbyConnections;

  // test en el default sah

  ResourceType selectedTab = ResourceType.foodWater;
  ResourceType get getSelectedTab => selectedTab;

  void setSelectedTab(ResourceType type) {
    selectedTab = type;
    notifyListeners();
  }

  List<Resource> resources = [];
  List<Resource> get getResources => resources;
  void setResources(List<Resource> res) {
    resources = res;
    notifyListeners();
  }

  List<Device> connectedDevices = [];
  List<Device> get getConnectedDevices => connectedDevices;
  void setConnectedDevices(List<Device> devices) {
    connectedDevices = devices;
    notifyListeners();
  }

  String? clusterId;

  late ResourceRepository repository;
  final ResourceRepository? _providedRepository;
  final DBService _dbService;
  //ehtemal akhali da injection bardo
  late SharedPreferences prefs;
  NearbyConnectionsBase? beacon;
  StreamSubscription<List<Resource>>? _resourceStreamSubscription;
  StreamSubscription<List<Resource>>? get resourceStreamSubscription =>
      _resourceStreamSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  void setIsLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // ---------- INIT & LISTENER SETUP ----------
  //test eh fil init

  //el is loading changes test

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      prefs = await SharedPreferences.getInstance();

      final modeStr = prefs.getString('dashboard_mode');
      final isInitiator = modeStr == 'initiator';

      beacon =
          beacon ??
          (isInitiator
              ? NearbyConnectionsInitiator()
              : NearbyConnectionsJoiner());

      repository =
          _providedRepository ??
          DbResourceRepository(dbService: _dbService, beacon: beacon!);

      beacon!.addListener(_onBeaconStateChanged);

      await beacon!.init(
        DeviceRepositoryImpl(_dbService),
        ClusterRepositoryImpl(_dbService),
        ClusterMemberRepositoryImpl(_dbService),
        ChatRepositoryImpl(_dbService),
        ChatMessageRepositoryImpl(_dbService),
      );

      // Initial load from DB
      await _reloadFromDb();

      // Listen to resource updates from the model
      _resourceStreamSubscription = Resource.resourceUpdateStream.listen((
        updatedResources,
      ) {
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
    beacon?.removeListener(_onBeaconStateChanged);
    _resourceStreamSubscription?.cancel();
    super.dispose();
  }

  // ---------- UI STATE ----------

  void changeTab(ResourceType newTab) {
    selectedTab = newTab;
    notifyListeners();
  }

  // ---------- DATA LOADING ----------

  Future<List<Resource>> fetchResources() async {
    return await repository.fetchResources();
  }

  Future<List<Device>> fetchConnectedDevices() async {
    return await repository.fetchConnectedDevices();
  }

  Future<void> postResource(String name, String description) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Ensure beacon and uuid are initialized
      if (beacon == null || beacon!.uuid == null) {
        throw Exception('Beacon service or device UUID not initialized');
      }

      final String userUuid = beacon!.uuid!;

      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.posted,
        resourceId: const Uuid().v4(),
        resourceType: selectedTab,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );

      await repository.insertResource(newResource);

      // Broadcast to others in cluster
      for (final device in connectedDevices) {
        if (device.uuid == userUuid) continue;
        await beacon!.sendMessage(device.endpointId, 'RESOURCES', {
          'resources': [newResource.toMap()],
        });
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

      // Ensure beacon and uuid are initialized
      if (beacon == null || beacon!.uuid == null) {
        throw Exception('Beacon service or device UUID not initialized');
      }

      final String userUuid = beacon!.uuid!;

      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.requested,
        resourceId: const Uuid().v4(),
        resourceType: selectedTab,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );

      await repository.insertResource(newResource);

      for (final device in connectedDevices) {
        if (device.uuid == userUuid) continue;
        await beacon!.sendMessage(device.endpointId, 'RESOURCES', {
          'resources': [newResource.toMap()],
        });
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
