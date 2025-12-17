import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/models/cluster_member.dart';

import 'package:beacon_project/repositories/mock/mock_device_repository.dart';
import 'package:beacon_project/repositories/mock/mock_cluster_repository.dart';
import 'package:beacon_project/repositories/mock/mock_cluster_member_repository.dart';
import 'package:beacon_project/repositories/mock/mock_chat_repository.dart';
import 'package:beacon_project/repositories/mock/mock_chat_message_repository.dart';

import 'mocks.mocks.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNearby mockNearby;
  late MockDeviceRepository mockDeviceRepo;
  late MockClusterRepository mockClusterRepo;
  late MockClusterMemberRepository mockClusterMemberRepo;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({'device_uuid': 'test-uuid-123'});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          return {0: 1, 1: 1, 2: 1, 3: 1, 4: 1, 5: 1};
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAndroidDeviceInfo') {
          return {
            'version': {'sdkInt': 33},
            'model': 'Test Device',
            'id': 'test-device-id',
          };
        }
        return null;
      },
    );
  });

  setUp(() {
    mockDeviceRepo = MockDeviceRepository();
    mockClusterRepo = MockClusterRepository();
    mockClusterMemberRepo = MockClusterMemberRepository();
    
    mockDeviceRepo.clear();
    mockClusterRepo.clear();
    mockClusterMemberRepo.clear();
    
    mockNearby = MockNearby();
  });

  tearDown(() {
    mockDeviceRepo.clear();
    mockClusterRepo.clear();
    mockClusterMemberRepo.clear();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      null,
    );
  });

  // ============================================================================
  // NEARBY CONNECTIONS BASE TESTS
  // ============================================================================
  group('NearbyConnectionsBase - Repository Operations', () {
    group('Device Repository', () {
      test('should insert and retrieve device', () async {
        final device = Device(
          uuid: 'device-uuid-456',
          deviceName: 'Test Device',
          endpointId: 'endpoint-456',
          status: 'Available',
          inRange: true,
        );

        await mockDeviceRepo.insertDevice(device);
        
        final retrieved = await mockDeviceRepo.getDeviceByUuid('device-uuid-456');
        expect(retrieved, isNotNull);
        expect(retrieved?.deviceName, equals('Test Device'));
        expect(retrieved?.inRange, isTrue);
      });

      test('should update device status', () async {
        final device = Device(
          uuid: 'device-uuid-789',
          deviceName: 'Joiner Device',
          endpointId: 'endpoint-789',
          status: 'Available',
          inRange: true,
        );
        await mockDeviceRepo.insertDevice(device);

        await mockDeviceRepo.updateDeviceStatus('device-uuid-789', 'Connected');

        final updatedDevice = await mockDeviceRepo.getDeviceByUuid('device-uuid-789');
        expect(updatedDevice?.status, equals('Connected'));
      });

      test('should mark device as online', () async {
        final device = Device(
          uuid: 'device-uuid-111',
          deviceName: 'Offline Device',
          endpointId: 'endpoint-111',
          status: 'Available',
          isOnline: false,
          inRange: true,
        );
        await mockDeviceRepo.insertDevice(device);

        await mockDeviceRepo.markDeviceOnline('device-uuid-111');

        final updatedDevice = await mockDeviceRepo.getDeviceByUuid('device-uuid-111');
        expect(updatedDevice?.isOnline, isTrue);
      });

      test('should mark device as offline', () async {
        final device = Device(
          uuid: 'device-uuid-222',
          deviceName: 'Online Device',
          endpointId: 'endpoint-222',
          status: 'Available',
          isOnline: true,
          inRange: true,
        );
        await mockDeviceRepo.insertDevice(device);

        await mockDeviceRepo.markDeviceOffline('device-uuid-222');

        final updatedDevice = await mockDeviceRepo.getDeviceByUuid('device-uuid-222');
        expect(updatedDevice?.isOnline, isFalse);
      });

      test('should update device endpoint', () async {
        final device = Device(
          uuid: 'device-uuid-333',
          deviceName: 'Test Device',
          endpointId: 'old-endpoint',
          status: 'Available',
          inRange: true,
        );
        await mockDeviceRepo.insertDevice(device);

        await mockDeviceRepo.updateDeviceEndpoint('device-uuid-333', 'new-endpoint');

        final updatedDevice = await mockDeviceRepo.getDeviceByUuid('device-uuid-333');
        expect(updatedDevice?.endpointId, equals('new-endpoint'));
      });

      test('should update device in range status', () async {
        final device = Device(
          uuid: 'device-range-test',
          deviceName: 'Range Device',
          endpointId: 'ep-range',
          status: 'Available',
          inRange: true,
        );
        await mockDeviceRepo.insertDevice(device);

        await mockDeviceRepo.updateDeviceInRange('device-range-test', false);

        final updatedDevice = await mockDeviceRepo.getDeviceByUuid('device-range-test');
        expect(updatedDevice?.inRange, isFalse);
      });

      test('should get devices in range', () async {
        await mockDeviceRepo.insertDevice(Device(
          uuid: 'device-in-range',
          deviceName: 'Near Device',
          endpointId: 'ep-1',
          status: 'Available',
          inRange: true,
        ));
        await mockDeviceRepo.insertDevice(Device(
          uuid: 'device-out-range',
          deviceName: 'Far Device',
          endpointId: 'ep-2',
          status: 'Available',
          inRange: false,
        ));

        final inRangeDevices = await mockDeviceRepo.getDevicesInRange();
        
        expect(inRangeDevices.length, equals(1));
        expect(inRangeDevices.first.uuid, equals('device-in-range'));
      });

      test('should get devices not in cluster', () async {
        const clusterId = 'cluster-123';
        const currentDeviceUuid = 'current-device';
        
        await mockDeviceRepo.insertDevice(Device(
          uuid: 'device-1',
          deviceName: 'Device 1',
          endpointId: 'ep-1',
          status: 'Available',
          inRange: true,
        ));
        await mockDeviceRepo.insertDevice(Device(
          uuid: 'device-2',
          deviceName: 'Device 2',
          endpointId: 'ep-2',
          status: 'Available',
          inRange: true,
        ));

        final availableDevices = await mockDeviceRepo.getDevicesNotInCluster(
          clusterId,
          currentDeviceUuid,
        );
        
        expect(availableDevices.length, equals(2));
        expect(availableDevices.every((d) => d.uuid != currentDeviceUuid), isTrue);
      });

      test('should delete device', () async {
        final device = Device(
          uuid: 'device-to-delete',
          deviceName: 'Delete Me',
          endpointId: 'ep-delete',
          status: 'Available',
          inRange: true,
        );
        await mockDeviceRepo.insertDevice(device);

        await mockDeviceRepo.deleteDevice('device-to-delete');

        final deletedDevice = await mockDeviceRepo.getDeviceByUuid('device-to-delete');
        expect(deletedDevice, isNull);
      });

      test('should return null for non-existent device', () async {
        final device = await mockDeviceRepo.getDeviceByUuid('non-existent-uuid');
        expect(device, isNull);
      });

      test('should get all devices', () async {
        await mockDeviceRepo.insertDevice(Device(
          uuid: 'device-1',
          deviceName: 'Device 1',
          endpointId: 'ep-1',
          status: 'Available',
          inRange: true,
        ));
        await mockDeviceRepo.insertDevice(Device(
          uuid: 'device-2',
          deviceName: 'Device 2',
          endpointId: 'ep-2',
          status: 'Available',
          inRange: true,
        ));

        final allDevices = await mockDeviceRepo.getAllDevices();
        expect(allDevices.length, equals(2));
      });
    });

    group('Cluster Repository', () {
      test('should insert and retrieve cluster', () async {
        final cluster = Cluster(
          clusterId: 'cluster-123',
          ownerUuid: 'owner-uuid-789',
          name: 'Test Cluster',
          ownerEndpointId: 'endpoint-owner',
        );

        await mockClusterRepo.insertCluster(cluster);

        final retrievedCluster = await mockClusterRepo.getClusterById('cluster-123');
        expect(retrievedCluster, isNotNull);
        expect(retrievedCluster?.name, equals('Test Cluster'));
      });

      test('should get all clusters', () async {
        await mockClusterRepo.insertCluster(Cluster(
          clusterId: 'cluster-1',
          ownerUuid: 'owner-1',
          name: 'Cluster 1',
          ownerEndpointId: 'ep-1',
        ));
        await mockClusterRepo.insertCluster(Cluster(
          clusterId: 'cluster-2',
          ownerUuid: 'owner-2',
          name: 'Cluster 2',
          ownerEndpointId: 'ep-2',
        ));

        final clusters = await mockClusterRepo.getAllClusters();
        expect(clusters.length, equals(2));
      });

      test('should update cluster', () async {
        final cluster = Cluster(
          clusterId: 'cluster-update',
          ownerUuid: 'owner-123',
          name: 'Original Name',
          ownerEndpointId: 'ep-1',
        );
        await mockClusterRepo.insertCluster(cluster);

        final updatedCluster = Cluster(
          clusterId: 'cluster-update',
          ownerUuid: 'owner-123',
          name: 'Updated Name',
          ownerEndpointId: 'ep-1',
        );
        await mockClusterRepo.updateCluster(updatedCluster);

        final retrieved = await mockClusterRepo.getClusterById('cluster-update');
        expect(retrieved?.name, equals('Updated Name'));
      });

      test('should delete cluster by ID', () async {
        final cluster = Cluster(
          clusterId: 'cluster-delete',
          ownerUuid: 'owner-123',
          name: 'Delete Me',
          ownerEndpointId: 'ep-1',
        );
        await mockClusterRepo.insertCluster(cluster);

        await mockClusterRepo.deleteCluster('cluster-delete');

        final deleted = await mockClusterRepo.getClusterById('cluster-delete');
        expect(deleted, isNull);
      });

      test('should delete cluster by owner', () async {
        final cluster = Cluster(
          clusterId: 'cluster-owner-test',
          ownerUuid: 'owner-123',
          name: 'Owner Cluster',
          ownerEndpointId: '',
        );
        await mockClusterRepo.insertCluster(cluster);

        await mockClusterRepo.deleteClusterByOwner('owner-123');

        final deletedCluster = await mockClusterRepo.getClusterById('cluster-owner-test');
        expect(deletedCluster, isNull);
      });

      test('should get cluster by owner UUID', () async {
        final cluster = Cluster(
          clusterId: 'cluster-123',
          ownerUuid: 'specific-owner',
          name: 'Owner Test',
          ownerEndpointId: 'ep-1',
        );
        await mockClusterRepo.insertCluster(cluster);

        final retrieved = await mockClusterRepo.getClusterByOwnerUuid('specific-owner');
        expect(retrieved, isNotNull);
        expect(retrieved?.clusterId, equals('cluster-123'));
      });

      test('should return null for non-existent cluster', () async {
        final cluster = await mockClusterRepo.getClusterById('non-existent-id');
        expect(cluster, isNull);
      });

      test('should return null for non-existent owner', () async {
        final cluster = await mockClusterRepo.getClusterByOwnerUuid('non-existent-owner');
        expect(cluster, isNull);
      });
    });

    group('Cluster Member Repository', () {
      test('should add cluster member', () async {
        const clusterId = 'cluster-123';
        const deviceUuid = 'joiner-uuid-456';
        
        final member = ClusterMember(
          clusterId: clusterId,
          deviceUuid: deviceUuid,
        );

        await mockClusterMemberRepo.insertMember(member);

        final isMember = await mockClusterMemberRepo.isMemberOfCluster(
          clusterId,
          deviceUuid,
        );
        expect(isMember, isTrue);
      });

      test('should get members by cluster ID', () async {
        const clusterId = 'cluster-123';
        
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: clusterId, deviceUuid: 'device-1'),
        );
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: clusterId, deviceUuid: 'device-2'),
        );

        final members = await mockClusterMemberRepo.getMembersByClusterId(clusterId);
        expect(members.length, equals(2));
      });

      test('should get members by device UUID', () async {
        const deviceUuid = 'multi-cluster-device';
        
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: 'cluster-1', deviceUuid: deviceUuid),
        );
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: 'cluster-2', deviceUuid: deviceUuid),
        );

        final memberships = await mockClusterMemberRepo.getMembersByDeviceUuid(deviceUuid);
        expect(memberships.length, equals(2));
      });

      test('should get specific member', () async {
        const clusterId = 'cluster-123';
        const deviceUuid = 'device-456';
        
        final member = ClusterMember(
          clusterId: clusterId,
          deviceUuid: deviceUuid,
        );
        await mockClusterMemberRepo.insertMember(member);

        final retrievedMember = await mockClusterMemberRepo.getMember(clusterId, deviceUuid);
        
        expect(retrievedMember, isNotNull);
        expect(retrievedMember?.clusterId, equals(clusterId));
        expect(retrievedMember?.deviceUuid, equals(deviceUuid));
      });

      test('should not add duplicate cluster member', () async {
        const clusterId = 'cluster-123';
        const deviceUuid = 'joiner-uuid-789';
        
        final member = ClusterMember(
          clusterId: clusterId,
          deviceUuid: deviceUuid,
        );

        await mockClusterMemberRepo.insertMember(member);
        await mockClusterMemberRepo.insertMember(member);

        final members = await mockClusterMemberRepo.getMembersByClusterId(clusterId);
        expect(members.length, equals(1));
      });

      test('should remove cluster member', () async {
        const clusterId = 'cluster-123';
        const deviceUuid = 'member-uuid-999';
        
        final member = ClusterMember(
          clusterId: clusterId,
          deviceUuid: deviceUuid,
        );
        await mockClusterMemberRepo.insertMember(member);

        await mockClusterMemberRepo.deleteMember(clusterId, deviceUuid);

        final isMember = await mockClusterMemberRepo.isMemberOfCluster(
          clusterId,
          deviceUuid,
        );
        expect(isMember, isFalse);
      });

      test('should delete all members by cluster', () async {
        const clusterId = 'cluster-delete-test';
        
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: clusterId, deviceUuid: 'device-1'),
        );
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: clusterId, deviceUuid: 'device-2'),
        );

        await mockClusterMemberRepo.deleteAllMembersByCluster(clusterId);

        final members = await mockClusterMemberRepo.getMembersByClusterId(clusterId);
        expect(members, isEmpty);
      });

      test('should delete all members by device', () async {
        const deviceUuid = 'leaving-device';
        
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: 'cluster-1', deviceUuid: deviceUuid),
        );
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: 'cluster-2', deviceUuid: deviceUuid),
        );

        await mockClusterMemberRepo.deleteAllMembersByDevice(deviceUuid);

        final memberships = await mockClusterMemberRepo.getMembersByDeviceUuid(deviceUuid);
        expect(memberships, isEmpty);
      });

      test('should return empty list for cluster with no members', () async {
        final members = await mockClusterMemberRepo.getMembersByClusterId('empty-cluster');
        expect(members, isEmpty);
      });

      test('should check membership correctly', () async {
        const clusterId = 'cluster-123';
        const memberUuid = 'member-device';
        const nonMemberUuid = 'non-member-device';
        
        await mockClusterMemberRepo.insertMember(
          ClusterMember(clusterId: clusterId, deviceUuid: memberUuid),
        );

        final isMember = await mockClusterMemberRepo.isMemberOfCluster(clusterId, memberUuid);
        final isNotMember = await mockClusterMemberRepo.isMemberOfCluster(clusterId, nonMemberUuid);

        expect(isMember, isTrue);
        expect(isNotMember, isFalse);
      });
    });
  });

  // ============================================================================
  // NEARBY CONNECTIONS INITIATOR TESTS
  // ============================================================================
  group('NearbyConnectionsInitiator Operations', () {
    late NearbyConnectionsInitiator initiator;

    setUpAll(() async {
      // Note: MissingPluginException errors are expected in unit tests
      // The Nearby plugin has no implementation in test environment
      initiator = NearbyConnectionsInitiator();
      await initiator.init(
        MockDeviceRepository(),
        MockClusterRepository(),
        MockClusterMemberRepository(),
        MockChatRepository(),
        MockChatMessageRepository(),  
      );
    });

    setUp(() {
      mockDeviceRepo.clear();
      mockClusterRepo.clear();
      mockClusterMemberRepo.clear();
    });

    group('Cluster Creation and Management', () {
      test('should create new cluster when none exists', () async {
        when(mockNearby.startAdvertising(
          any,
          any,
          serviceId: anyNamed('serviceId'),
          onConnectionInitiated: anyNamed('onConnectionInitiated'),
          onConnectionResult: anyNamed('onConnectionResult'),
          onDisconnected: anyNamed('onDisconnected'),
        )).thenAnswer((_) async => true);
        
        when(mockNearby.startDiscovery(
          any,
          any,
          serviceId: anyNamed('serviceId'),
          onEndpointFound: anyNamed('onEndpointFound'),
          onEndpointLost: anyNamed('onEndpointLost'),
        )).thenAnswer((_) async => true);

        await initiator.startCommunication();

        expect(initiator.createdCluster, isNotNull);
      });
    });

    group('Device Discovery', () {
      test('should track available devices', () async {
        final devices = initiator.availableDevices;
        expect(devices, isNotNull);
        expect(devices, isList);
      });
    });

    group('Connection Management', () {
      test('should track connected endpoints', () async {
        final connectedEndpoints = initiator.connectedEndpoints;
        expect(connectedEndpoints, isNotNull);
        expect(connectedEndpoints, isList);
      });

      test('should track active connections', () async {
        final activeConnections = initiator.activeConnections;
        expect(activeConnections, isNotNull);
        expect(activeConnections, isMap);
      });
    });
  });

  // ============================================================================
  // NEARBY CONNECTIONS JOINER TESTS
  // ============================================================================
  group('NearbyConnectionsJoiner Operations', () {
    late NearbyConnectionsJoiner joiner;

    setUpAll(() async {
      // Note: MissingPluginException errors are expected in unit tests
      joiner = NearbyConnectionsJoiner();
      await joiner.init(
        MockDeviceRepository(),
        MockClusterRepository(),
        MockClusterMemberRepository(),
        MockChatRepository(),
        MockChatMessageRepository(), 

      );
    });

    setUp(() {
      mockDeviceRepo.clear();
      mockClusterRepo.clear();
      mockClusterMemberRepo.clear();
    });

    group('Cluster Discovery', () {
      test('should track discovered clusters', () async {
        final discoveredClusters = joiner.discoveredClusters;
        expect(discoveredClusters, isNotNull);
        expect(discoveredClusters, isList);
      });

      test('should handle cluster information', () async {
        final joinedCluster = joiner.joinedCluster;
        expect(joinedCluster, isNull); // Initially not joined
      });
    });

    group('Cluster Joining', () {
      test('should track joined cluster state', () async {
        expect(joiner.joinedCluster, isNull);
      });
    });

    group('Invitation Handling', () {
      test('should track pending invite info', () async {
        final pendingInvite = joiner.pendingInviteInfo;
        expect(pendingInvite, isNull); // Initially no pending invites
      });

      test('should track pending invite endpoint', () async {
        final pendingEndpoint = joiner.pendingInviteEndpointId;
        expect(pendingEndpoint, isNull);
      });
    });

    group('Connection Management', () {
      test('should track connected endpoints', () async {
        final connectedEndpoints = joiner.connectedEndpoints;
        expect(connectedEndpoints, isNotNull);
        expect(connectedEndpoints, isList);
      });

      test('should track active connections', () async {
        final activeConnections = joiner.activeConnections;
        expect(activeConnections, isNotNull);
        expect(activeConnections, isMap);
      });
    });
  });
}
