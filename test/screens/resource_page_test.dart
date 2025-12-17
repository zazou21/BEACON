import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/viewmodels/resource_viewmodel.dart';
import 'package:beacon_project/models/resource.dart';
import 'package:beacon_project/screens/resources_page.dart';
import 'package:beacon_project/repositories/resource_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mocks.mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/repositories/mock/mock_device_repository.dart';
import 'package:beacon_project/repositories/mock/mock_cluster_repository.dart';
import 'package:beacon_project/repositories/mock/mock_cluster_member_repository.dart';


void main() {
  late MockNearbyConnectionsBase beacon;
  late MockResourceRepository repo;
  late ResourceViewModel vm;
  late DeviceRepository deviceRepo;
  late ClusterRepository clusterRepo;
  late ClusterMemberRepository clusterMemberRepo;


  setUp(() async {
    SharedPreferences.setMockInitialValues({'dashboard_mode': 'initiator'});
    deviceRepo= MockDeviceRepository();
    clusterRepo= MockClusterRepository();
    clusterMemberRepo= MockClusterMemberRepository();

    
    beacon = MockNearbyConnectionsBase();
    when(beacon.init(deviceRepo,clusterRepo,clusterMemberRepo)).thenAnswer((_) async {});
    when(beacon.uuid).thenReturn('uuid');
    when(beacon.deviceName).thenReturn('device');
    when(beacon.addListener(any)).thenReturn(null);

    repo = MockResourceRepository(
      mockResources: [],
      mockDevices: [],
    );

    vm = ResourceViewModel(nearbyConnections: beacon, repository: repo);
    await vm.init();
  });

  group('Resource page tests', () {
    testWidgets('ResourcePage displays correctly', (WidgetTester tester) async {
      vm.setIsLoading(false);
      
      await tester.pumpWidget(
        MaterialApp(home: ResourcePage(viewModel: vm)),
      );
      
      await tester.pump();

      // Verify that the ResourcePage contains expected elements
      expect(find.byType(ResourceTabs), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Share or request emergency resources'), findsOneWidget);
    });

    testWidgets('ResourcePage displays loading correctly', (WidgetTester tester) async {
      vm.setIsLoading(true);
      
      await tester.pumpWidget(
        MaterialApp(home: ResourcePage(viewModel: vm)),
      );
      
      await tester.pump();

      // Verify that the loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ResourcePage displays resources correctly', (WidgetTester tester) async {
      vm.setIsLoading(false);
      vm.setResources([
        Resource(
          resourceId: '1',
          resourceName: 'Water Bottle',
          resourceType: ResourceType.foodWater,
          resourceDescription: 'Clean drinking water',
          userUuid: 'user1',
          resourceStatus: ResourceStatus.posted,
        ),
      ]);
      
      await tester.pumpWidget(
        MaterialApp(home: ResourcePage(viewModel: vm)),
      );
      
      await tester.pump();

      // Verify that the resource is displayed
      expect(find.text('Water Bottle'), findsOneWidget);
      expect(find.text('Clean drinking water'), findsOneWidget);
    });

    testWidgets('Resource Page displays empty resource list', (WidgetTester tester) async {
      vm.setIsLoading(false);
      vm.setResources([]);
      
      await tester.pumpWidget(
        MaterialApp(home: ResourcePage(viewModel: vm)),
      );
      
      await tester.pump();

      expect(find.text('No recent activity'), findsOneWidget);
    });

    testWidgets('Resource page displays the correct tab', (WidgetTester tester) async {
      vm.setIsLoading(false);
      vm.setSelectedTab(ResourceType.medical);
      vm.setResources([
        Resource(
          resourceId: '2',
          resourceName: 'Bandages',
          resourceType: ResourceType.medical,
          resourceDescription: 'Sterile bandages',
          userUuid: 'user2',
          resourceStatus: ResourceStatus.posted,
        ),
        Resource(
          resourceId: '3',
          resourceName: 'Canned Food',
          resourceType: ResourceType.foodWater,
          resourceDescription: 'Canned beans',
          userUuid: 'user3',
          resourceStatus: ResourceStatus.posted,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: ResourcePage(viewModel: vm)),
      );
      
      await tester.pump();

      expect(find.text('Bandages'), findsOneWidget);
      expect(find.text('Canned Food'), findsNothing);
    });
  });
}