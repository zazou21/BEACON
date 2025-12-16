// test/services/nearby_connections_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nearby_connections/nearby_connections.dart' as nc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/services/nearby_connections/payload_strategy_factory.dart';
import 'package:beacon_project/services/nearby_connections/payload_strategy.dart';
import 'package:beacon_project/services/nearby_connections/mark_online_payload_strategy.dart';
import 'package:beacon_project/services/nearby_connections/transfer_ownership_payload_strategy.dart';
import 'package:beacon_project/services/nearby_connections/owner_changed_payload_strategy.dart';
import 'package:beacon_project/services/nearby_connections/ownership_transferred_payload_strategy.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/models/device.dart';



// Generate mocks with this command: flutter pub run build_runner build
@GenerateMocks([
  nc.Nearby,
  Database,
  DBService,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNearby mockNearby;
  late MockDatabase mockDb;
  late MockDBService mockDbService;

  setUp(() {
    mockNearby = MockNearby();
    mockDb = MockDatabase();
    mockDbService = MockDBService();

    // Set up DBService mock
    when(mockDbService.database).thenAnswer((_) async => mockDb);
  });

  group('NearbyConnectionsBase', () {
    test('init() sets device name and uuid correctly', () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'test-uuid-123'});

      final testBeacon = _TestNearbyConnectionsBase();
      await testBeacon.init();

      expect(testBeacon.uuid, 'test-uuid-123');
      expect(testBeacon.deviceName, isNotEmpty);
    });

    test('init() generates new uuid if not exists', () async {
      SharedPreferences.setMockInitialValues({});

      final testBeacon = _TestNearbyConnectionsBase();
      await testBeacon.init();

      final prefs = await SharedPreferences.getInstance();
      final storedUuid = prefs.getString('device_uuid');

      expect(storedUuid, isNotNull);
      expect(testBeacon.uuid, storedUuid);
    });

    test('sendMessage() encodes and sends payload correctly', () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'test-uuid'});
      final testBeacon = _TestNearbyConnectionsBase();
      await testBeacon.init();

      when(mockNearby.sendBytesPayload(any, any))
          .thenAnswer((_) async => {});

      final testData = {'key': 'value', 'number': 42};
      await testBeacon.sendMessage('endpoint-1', 'TEST_TYPE', testData);

      final captured = verify(mockNearby.sendBytesPayload('endpoint-1', captureAny))
          .captured
          .single as Uint8List;

      final decodedPayload = jsonDecode(utf8.decode(captured));
      expect(decodedPayload['type'], 'TEST_TYPE');
      expect(decodedPayload['data'], testData);
    });

    test('onPayloadReceived() dispatches to correct strategy', () async {
      final testBeacon = _TestNearbyConnectionsBase();
      await testBeacon.init();

      when(mockDb.query('devices',
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
              limit: anyNamed('limit')))
          .thenAnswer((_) async => [
                {'uuid': 'device-1'}
              ]);
      when(mockDb.update('devices', any,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      final payload = nc.Payload(
        id: 1,
        type: nc.PayloadType.BYTES,
        bytes: Uint8List.fromList(utf8.encode(jsonEncode({
          'type': 'MARK_ONLINE',
          'data': {'uuid': 'device-1'}
        }))),
      );

      testBeacon.onPayloadReceived('endpoint-1', payload);

      await Future.delayed(Duration(milliseconds: 100));

      verify(mockDb.update('devices', any,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .called(1);
    });

    test('stopAll() clears all connections and state', () async {
      final testBeacon = _TestNearbyConnectionsBase();
      await testBeacon.init();

      testBeacon.activeConnections['ep1'] = 'device-1';
      testBeacon.connectedEndpoints.add('ep1');

      when(mockNearby.stopAdvertising()).thenAnswer((_) async => {});
      when(mockNearby.stopDiscovery()).thenAnswer((_) async => {});
      when(mockNearby.stopAllEndpoints()).thenAnswer((_) async => {});

      await testBeacon.stopAll();

      expect(testBeacon.connectedEndpoints, isEmpty);
      expect(testBeacon.activeConnections, isEmpty);
      verify(mockNearby.stopAdvertising()).called(1);
      verify(mockNearby.stopDiscovery()).called(1);
      verify(mockNearby.stopAllEndpoints()).called(1);
    });
  });

  group('NearbyConnectionsInitiator', () {
    test('startCommunication() creates new cluster when none exists', () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'owner-uuid'});

      when(mockDb.query('clusters',
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
              limit: anyNamed('limit')))
          .thenAnswer((_) async => []);

      when(mockDb.transaction(any)).thenAnswer((invocation) async {
        final callback = invocation.positionalArguments[0] as Function;
        return await callback(mockDb);
      });

      when(mockDb.insert('clusters', any,
              conflictAlgorithm: anyNamed('conflictAlgorithm')))
          .thenAnswer((_) async => 1);
      when(mockDb.insert('cluster_members', any,
              conflictAlgorithm: anyNamed('conflictAlgorithm')))
          .thenAnswer((_) async => 1);

      when(mockNearby.startAdvertising(any, any,
              serviceId: anyNamed('serviceId'),
              onConnectionInitiated: anyNamed('onConnectionInitiated'),
              onConnectionResult: anyNamed('onConnectionResult'),
              onDisconnected: anyNamed('onDisconnected')))
          .thenAnswer((_) async => true);

      when(mockNearby.startDiscovery(any, any,
              serviceId: anyNamed('serviceId'),
              onEndpointFound: anyNamed('onEndpointFound'),
              onEndpointLost: anyNamed('onEndpointLost')))
          .thenAnswer((_) async => true);

      final initiator = NearbyConnectionsInitiator();
      await initiator.init();
      // Note: You'll need to inject mockDb into initiator or use dependency injection

      verify(mockDb.insert('clusters', any,
              conflictAlgorithm: anyNamed('conflictAlgorithm')))
          .called(1);
      verify(mockNearby.startAdvertising(any, any,
              serviceId: anyNamed('serviceId'),
              onConnectionInitiated: anyNamed('onConnectionInitiated'),
              onConnectionResult: anyNamed('onConnectionResult'),
              onDisconnected: anyNamed('onDisconnected')))
          .called(1);
    });

    test('startCommunication() uses existing cluster', () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'owner-uuid'});

      when(mockDb.query('clusters',
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
              limit: anyNamed('limit')))
          .thenAnswer((_) async => [
                {
                  'clusterId': 'existing-cluster',
                  'ownerUuid': 'owner-uuid',
                  'ownerEndpointId': '',
                  'name': 'Test Cluster',
                  'createdAt': DateTime.now().millisecondsSinceEpoch,
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                }
              ]);

      when(mockNearby.startAdvertising(any, any,
              serviceId: anyNamed('serviceId'),
              onConnectionInitiated: anyNamed('onConnectionInitiated'),
              onConnectionResult: anyNamed('onConnectionResult'),
              onDisconnected: anyNamed('onDisconnected')))
          .thenAnswer((_) async => true);

      when(mockNearby.startDiscovery(any, any,
              serviceId: anyNamed('serviceId'),
              onEndpointFound: anyNamed('onEndpointFound'),
              onEndpointLost: anyNamed('onEndpointLost')))
          .thenAnswer((_) async => true);

      final initiator = NearbyConnectionsInitiator();
      await initiator.init();

      expect(initiator.createdCluster?.clusterId, 'existing-cluster');
      verify(mockNearby.startAdvertising(any, any,
              serviceId: anyNamed('serviceId'),
              onConnectionInitiated: anyNamed('onConnectionInitiated'),
              onConnectionResult: anyNamed('onConnectionResult'),
              onDisconnected: anyNamed('onDisconnected')))
          .called(1);
    });

    test('transferOwnershipBeforeDisconnect() sends transfer message', () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'owner-uuid'});

      when(mockDb.query('cluster_members',
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => [
                {'clusterId': 'cluster-1', 'deviceUuid': 'joiner-uuid'}
              ]);

      when(mockDb.query('devices',
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => [
                {'uuid': 'joiner-uuid', 'deviceName': 'Joiner Device'}
              ]);

      when(mockNearby.sendBytesPayload(any, any))
          .thenAnswer((_) async => {});

      final initiator = NearbyConnectionsInitiator();
      await initiator.init();
      
      // Simulate having a cluster and connected endpoints
      initiator.activeConnections['ep-1'] = 'joiner-uuid';
      initiator.connectedEndpoints.add('ep-1');

      await initiator.transferOwnershipBeforeDisconnect();

      verify(mockNearby.sendBytesPayload('ep-1', any)).called(greaterThan(0));
    });
  });

  group('NearbyConnectionsJoiner', () {
    test('startCommunication() starts discovery and advertising', () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'joiner-uuid'});

      when(mockDb.query('cluster_members',
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
              limit: anyNamed('limit')))
          .thenAnswer((_) async => []);

      when(mockNearby.startAdvertising(any, any,
              serviceId: anyNamed('serviceId'),
              onConnectionInitiated: anyNamed('onConnectionInitiated'),
              onConnectionResult: anyNamed('onConnectionResult'),
              onDisconnected: anyNamed('onDisconnected')))
          .thenAnswer((_) async => true);

      when(mockNearby.startDiscovery(any, any,
              serviceId: anyNamed('serviceId'),
              onEndpointFound: anyNamed('onEndpointFound'),
              onEndpointLost: anyNamed('onEndpointLost')))
          .thenAnswer((_) async => true);

      final joiner = NearbyConnectionsJoiner();
      await joiner.init();

      verify(mockNearby.startAdvertising(
        argThat(contains('as|joiner-uuid')),
        any,
        serviceId: anyNamed('serviceId'),
        onConnectionInitiated: anyNamed('onConnectionInitiated'),
        onConnectionResult: anyNamed('onConnectionResult'),
        onDisconnected: anyNamed('onDisconnected'),
      )).called(1);
    });

    test('disconnectFromCluster() removes cluster membership', () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'joiner-uuid'});

      when(mockDb.delete('cluster_members',
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      when(mockDb.update('devices', any,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      when(mockNearby.disconnectFromEndpoint(any))
          .thenAnswer((_) async => {});

      final joiner = NearbyConnectionsJoiner();
      await joiner.init();

      // Simulate being in a cluster
      joiner.activeConnections['ep-1'] = 'owner-uuid';
      joiner.connectedEndpoints.add('ep-1');

      await joiner.disconnectFromCluster();

      expect(joiner.joinedCluster, isNull);
      expect(joiner.connectedEndpoints, isEmpty);
      verify(mockDb.delete('cluster_members',
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .called(1);
    });
  });

  group('Payload Strategies', () {
    test('MarkOnlinePayloadStrategy marks device as online', () async {
      final testBeacon = _TestNearbyConnectionsBase();
      final strategy = MarkOnlinePayloadStrategy(testBeacon);

      when(mockDb.query('devices',
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
              limit: anyNamed('limit')))
          .thenAnswer((_) async => [
                {'uuid': 'device-1', 'deviceName': 'Test Device'}
              ]);

      when(mockDb.update('devices', any,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      await strategy.handle('endpoint-1', {'uuid': 'device-1'});

      final captured = verify(mockDb.update('devices', captureAny,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .captured
          .single as Map<String, dynamic>;

      expect(captured['isOnline'], 1);
      expect(captured['lastSeen'], isNotNull);
    });

    test('TransferOwnershipPayloadStrategy updates cluster when I am new owner',
        () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'new-owner-uuid'});

      final testBeacon = _TestNearbyConnectionsBase();
      await testBeacon.init();

      final strategy = TransferOwnershipPayloadStrategy(testBeacon);

      when(mockDb.transaction(any)).thenAnswer((invocation) async {
        final callback = invocation.positionalArguments[0] as Function;
        return await callback(mockDb);
      });

      when(mockDb.update('clusters', any,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      when(mockDb.insert('devices', any,
              conflictAlgorithm: anyNamed('conflictAlgorithm')))
          .thenAnswer((_) async => 1);

      when(mockDb.insert('cluster_members', any,
              conflictAlgorithm: anyNamed('conflictAlgorithm')))
          .thenAnswer((_) async => 1);

      when(mockDb.delete('cluster_members',
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      await strategy.handle('endpoint-1', {
        'clusterId': 'cluster-1',
        'clusterName': 'Test Cluster',
        'newOwnerUuid': 'new-owner-uuid',
        'oldOwnerUuid': 'old-owner-uuid',
        'members': [
          {'clusterId': 'cluster-1', 'deviceUuid': 'new-owner-uuid'}
        ],
        'devices': [
          {'uuid': 'new-owner-uuid', 'deviceName': 'New Owner Device'}
        ],
      });

      verify(mockDb.update('clusters', any,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .called(1);
      verify(mockDb.insert('devices', any,
              conflictAlgorithm: anyNamed('conflictAlgorithm')))
          .called(1);
    });

    test('TransferOwnershipPayloadStrategy ignores when not new owner',
        () async {
      SharedPreferences.setMockInitialValues({'device_uuid': 'other-uuid'});

      final testBeacon = _TestNearbyConnectionsBase();
      await testBeacon.init();

      final strategy = TransferOwnershipPayloadStrategy(testBeacon);

      await strategy.handle('endpoint-1', {
        'clusterId': 'cluster-1',
        'clusterName': 'Test Cluster',
        'newOwnerUuid': 'new-owner-uuid',
        'oldOwnerUuid': 'old-owner-uuid',
        'members': [],
        'devices': [],
      });

      verifyNever(mockDb.transaction(any));
    });

    test('OwnerChangedPayloadStrategy updates cluster owner', () async {
      final testBeacon = _TestNearbyConnectionsBase();
      final strategy = OwnerChangedPayloadStrategy(testBeacon);

      when(mockDb.transaction(any)).thenAnswer((invocation) async {
        final callback = invocation.positionalArguments[0] as Function;
        return await callback(mockDb);
      });

      when(mockDb.update('clusters', any,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      when(mockDb.delete('cluster_members',
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      when(mockDb.update('devices', any,
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => 1);

      await strategy.handle('endpoint-1', {
        'clusterId': 'cluster-1',
        'newOwnerUuid': 'new-owner',
        'oldOwnerUuid': 'old-owner',
      });

      verify(mockDb.update('clusters', {'ownerUuid': 'new-owner'},
              where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .called(1);
      verify(mockDb.delete('cluster_members',
              where: anyNamed('where'),
              whereArgs: ['cluster-1', 'old-owner'])).called(1);
    });

    test('OwnershipTransferredPayloadStrategy just notifies', () async {
      final testBeacon = _TestNearbyConnectionsBase();
      final strategy = OwnershipTransferredPayloadStrategy(testBeacon);

      await strategy.handle('endpoint-1', {
        'clusterId': 'cluster-1',
        'newOwnerUuid': 'new-owner',
      });

      expect(testBeacon.notified, isTrue);
    });
  });

  group('PayloadStrategyFactory', () {
    test('getHandler() returns correct strategy for each type', () {
      final testBeacon = _TestNearbyConnectionsBase();
      PayloadStrategyFactory.initialize(testBeacon);

      expect(PayloadStrategyFactory.getHandler('MARK_ONLINE'),
          isA<MarkOnlinePayloadStrategy>());
      expect(PayloadStrategyFactory.getHandler('TRANSFER_OWNERSHIP'),
          isA<TransferOwnershipPayloadStrategy>());
      expect(PayloadStrategyFactory.getHandler('OWNER_CHANGED'),
          isA<OwnerChangedPayloadStrategy>());
      expect(PayloadStrategyFactory.getHandler('OWNERSHIP_TRANSFERRED'),
          isA<OwnershipTransferredPayloadStrategy>());
    });

    test('getHandler() throws when not initialized', () {
      PayloadStrategyFactory._beacon = null; // Reset

      expect(
        () => PayloadStrategyFactory.getHandler('MARK_ONLINE'),
        throwsStateError,
      );
    });
  });
}

// Test helper class
class _TestNearbyConnectionsBase extends NearbyConnectionsBase {
  bool notified = false;

  @override
  Future<void> startCommunication() async {}

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  void notifyListeners() {
    notified = true;
    super.notifyListeners();
  }

  // Expose protected members for testing
  Map<String, String> get activeConnections => _activeConnections;
  List<String> get connectedEndpoints => _connectedEndpoints;
}
