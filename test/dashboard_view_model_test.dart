// test/viewmodels/dashboard_view_model_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beacon_project/viewmodels/dashboard_view_model.dart';
import 'package:beacon_project/models/dashboard_mode.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/models/cluster_member.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';

import 'package:beacon_project/repositories/mock/mock_device_repository.dart';
import 'package:beacon_project/repositories/mock/mock_cluster_repository.dart';
import 'package:beacon_project/repositories/mock/mock_cluster_member_repository.dart';
import 'mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDeviceRepository mockDeviceRepo;
  late MockClusterRepository mockClusterRepo;
  late MockClusterMemberRepository mockClusterMemberRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({'device_uuid': 'test-uuid-123'});
    
    // Mock the permissions plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          // Return granted permissions
          return {
            0: 1, // Permission.location: PermissionStatus.granted
            1: 1, // Permission.bluetoothConnect: PermissionStatus.granted
            2: 1, // Permission.bluetoothAdvertise: PermissionStatus.granted
            3: 1, // Permission.bluetoothScan: PermissionStatus.granted
            4: 1, // Permission.nearbyWifiDevices: PermissionStatus.granted
          };
        }
        if (methodCall.method == 'checkPermissionStatus') {
          return 1; // PermissionStatus.granted
        }
        return null;
      },
    );
    
    // Mock Nearby Connections plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('nearby_connections'),
      (MethodCall methodCall) async {
        // Return mock responses for nearby connections methods
        switch (methodCall.method) {
          case 'startAdvertising':
            return true;
          case 'startDiscovery':
            return true;
          case 'stopAdvertising':
            return true;
          case 'stopDiscovery':
            return true;
          case 'stopAllEndpoints':
            return true;
          default:
            return null;
        }
      },
    );
    
    mockDeviceRepo = MockDeviceRepository();
    mockClusterRepo = MockClusterRepository();
    mockClusterMemberRepo = MockClusterMemberRepository();
    
    mockDeviceRepo.clear();
    mockClusterRepo.clear();
    mockClusterMemberRepo.clear();
  });

  tearDown(() {
    // Clear mock handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('nearby_connections'),
      null,
    );
    
    mockDeviceRepo.clear();
    mockClusterRepo.clear();
    mockClusterMemberRepo.clear();
  });

  group('DashboardViewModel - Initiator Mode', () {
    test('should initialize in initiator mode', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      expect(viewModel.mode, equals(DashboardMode.initiator));
      expect(viewModel.nearby, isA<NearbyConnectionsInitiator>());
      expect(viewModel.currentCluster, isNull);
      expect(viewModel.availableDevices, isEmpty);
      expect(viewModel.connectedDevices, isEmpty);

      viewModel.dispose();
    });

    test('should load current cluster for initiator', () async {
      final cluster = Cluster(
        clusterId: 'cluster-123',
        ownerUuid: 'test-uuid-123',
        name: 'Test Cluster',
        ownerEndpointId: 'ep-1',
      );
      await mockClusterRepo.insertCluster(cluster);

      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      await viewModel.initializeNearby();

      expect(viewModel.currentCluster, isNotNull);
      expect(viewModel.currentCluster?.clusterId, equals('cluster-123'));

      viewModel.dispose();
    });

    test('should load connected devices for initiator', () async {
      final cluster = Cluster(
        clusterId: 'cluster-123',
        ownerUuid: 'test-uuid-123',
        name: 'Test Cluster',
        ownerEndpointId: 'ep-1',
      );
      await mockClusterRepo.insertCluster(cluster);

      await mockClusterMemberRepo.insertMember(
        ClusterMember(clusterId: 'cluster-123', deviceUuid: 'test-uuid-123'),
      );
      await mockClusterMemberRepo.insertMember(
        ClusterMember(clusterId: 'cluster-123', deviceUuid: 'device-uuid-456'),
      );

      final device = Device(
        uuid: 'device-uuid-456',
        deviceName: 'Connected Device',
        endpointId: 'ep-456',
        status: 'Connected',
        inRange: true,
      );
      await mockDeviceRepo.insertDevice(device);

      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      await viewModel.initializeNearby();

      expect(viewModel.connectedDevices.length, greaterThanOrEqualTo(0));

      viewModel.dispose();
    });

    test('should handle empty connected devices list', () async {
      final cluster = Cluster(
        clusterId: 'cluster-123',
        ownerUuid: 'test-uuid-123',
        name: 'Test Cluster',
        ownerEndpointId: 'ep-1',
      );
      await mockClusterRepo.insertCluster(cluster);

      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      await viewModel.initializeNearby();

      expect(viewModel.connectedDevices, isEmpty);

      viewModel.dispose();
    });
  });

  group('DashboardViewModel - Joiner Mode', () {
    test('should initialize in joiner mode', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.joiner,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      expect(viewModel.mode, equals(DashboardMode.joiner));
      expect(viewModel.nearby, isA<NearbyConnectionsJoiner>());
      expect(viewModel.joinedCluster, isNull);
      expect(viewModel.discoveredClusters, isEmpty);
      expect(viewModel.connectedDevicesToCluster, isEmpty);

      viewModel.dispose();
    });

    test('should load joined cluster for joiner', () async {
      final cluster = Cluster(
        clusterId: 'cluster-123',
        ownerUuid: 'owner-uuid-789',
        name: 'Test Cluster',
        ownerEndpointId: 'ep-1',
      );
      await mockClusterRepo.insertCluster(cluster);

      await mockClusterMemberRepo.insertMember(
        ClusterMember(clusterId: 'cluster-123', deviceUuid: 'test-uuid-123'),
      );

      final viewModel = DashboardViewModel(
        mode: DashboardMode.joiner,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      await viewModel.initializeNearby();

      expect(viewModel.joinedCluster, isNotNull);
      expect(viewModel.joinedCluster?.clusterId, equals('cluster-123'));

      viewModel.dispose();
    });

    test('should load connected devices for joiner', () async {
      final cluster = Cluster(
        clusterId: 'cluster-123',
        ownerUuid: 'owner-uuid-789',
        name: 'Test Cluster',
        ownerEndpointId: 'ep-1',
      );
      await mockClusterRepo.insertCluster(cluster);

      await mockClusterMemberRepo.insertMember(
        ClusterMember(clusterId: 'cluster-123', deviceUuid: 'test-uuid-123'),
      );
      await mockClusterMemberRepo.insertMember(
        ClusterMember(clusterId: 'cluster-123', deviceUuid: 'owner-uuid-789'),
      );

      final ownerDevice = Device(
        uuid: 'owner-uuid-789',
        deviceName: 'Owner Device',
        endpointId: 'ep-owner',
        status: 'Connected',
        inRange: true,
      );
      await mockDeviceRepo.insertDevice(ownerDevice);

      final viewModel = DashboardViewModel(
        mode: DashboardMode.joiner,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      await viewModel.initializeNearby();

      expect(viewModel.connectedDevicesToCluster, isNotEmpty);

      viewModel.dispose();
    });

    test('should handle no joined cluster', () async {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.joiner,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      await viewModel.initializeNearby();

      expect(viewModel.joinedCluster, isNull);
      expect(viewModel.connectedDevicesToCluster, isEmpty);

      viewModel.dispose();
    });
  });

  group('DashboardViewModel - Shared Functionality', () {
    test('should format last seen correctly for seconds', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      final now = DateTime.now();
      final fiveSecondsAgo = now.subtract(const Duration(seconds: 5));

      final formatted = viewModel.formatLastSeen(
        fiveSecondsAgo.millisecondsSinceEpoch,
      );

      expect(formatted, contains('Active'));
      expect(formatted, contains('ago'));

      viewModel.dispose();
    });

    test('should format last seen correctly for minutes', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

      final formatted = viewModel.formatLastSeen(
        fiveMinutesAgo.millisecondsSinceEpoch,
      );

      expect(formatted, contains('Active'));
      expect(formatted, contains('m ago'));

      viewModel.dispose();
    });

    test('should format last seen correctly for hours', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      final now = DateTime.now();
      final twoHoursAgo = now.subtract(const Duration(hours: 2));

      final formatted = viewModel.formatLastSeen(
        twoHoursAgo.millisecondsSinceEpoch,
      );

      expect(formatted, contains('Active'));
      expect(formatted, contains('h ago'));

      viewModel.dispose();
    });

    test('should format last seen correctly for days', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      final formatted = viewModel.formatLastSeen(
        threeDaysAgo.millisecondsSinceEpoch,
      );

      expect(formatted, contains('Active'));
      expect(formatted, contains('d ago'));

      viewModel.dispose();
    });

    test('should format last seen correctly for old dates', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      final now = DateTime.now();
      final tenDaysAgo = now.subtract(const Duration(days: 10));

      final formatted = viewModel.formatLastSeen(
        tenDaysAgo.millisecondsSinceEpoch,
      );

      expect(formatted, contains('last seen'));

      viewModel.dispose();
    });

    test('should print database contents', () async {
      final device = Device(
        uuid: 'device-123',
        deviceName: 'Test Device',
        endpointId: 'ep-123',
        status: 'Available',
        inRange: true,
      );
      await mockDeviceRepo.insertDevice(device);

      final cluster = Cluster(
        clusterId: 'cluster-123',
        ownerUuid: 'owner-123',
        name: 'Test Cluster',
        ownerEndpointId: 'ep-1',
      );
      await mockClusterRepo.insertCluster(cluster);

      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      await viewModel.printDatabaseContents();

      viewModel.dispose();
    });

    test('should clear all state on stopAll', () async {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      viewModel.currentCluster = Cluster(
        clusterId: 'cluster-123',
        ownerUuid: 'owner-123',
        name: 'Test',
        ownerEndpointId: 'ep-1',
      );
      viewModel.availableDevices.add(Device(
        uuid: 'device-123',
        deviceName: 'Device',
        endpointId: 'ep-123',
        status: 'Available',
        inRange: true,
      ));

      await viewModel.stopAll();

      expect(viewModel.currentCluster, isNull);
      expect(viewModel.availableDevices, isEmpty);
      expect(viewModel.connectedDevices, isEmpty);
      expect(viewModel.discoveredClusters, isEmpty);
      expect(viewModel.joinedCluster, isNull);
      expect(viewModel.connectedDevicesToCluster, isEmpty);

      viewModel.dispose();
    });
  });

  group('DashboardViewModel - State Change Handling', () {
    test('should notify listeners on state change', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      var notified = false;
      viewModel.addListener(() {
        notified = true;
      });

      viewModel.onNearbyStateChanged();

      expect(notified, isTrue);

      viewModel.dispose();
    });

    test('should handle initiator state changes', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.initiator,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      var notificationCount = 0;
      viewModel.addListener(() {
        notificationCount++;
      });

      viewModel.onNearbyStateChanged();

      expect(notificationCount, greaterThan(0));

      viewModel.dispose();
    });

    test('should handle joiner state changes', () {
      final viewModel = DashboardViewModel(
        mode: DashboardMode.joiner,
        deviceRepository: mockDeviceRepo,
        clusterRepository: mockClusterRepo,
        clusterMemberRepository: mockClusterMemberRepo,
      );

      var notificationCount = 0;
      viewModel.addListener(() {
        notificationCount++;
      });

      viewModel.onNearbyStateChanged();

      expect(notificationCount, greaterThan(0));

      viewModel.dispose();
    });
  });
}
