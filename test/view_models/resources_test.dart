
import 'package:beacon_project/repositories/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beacon_project/viewmodels/resource_viewmodel.dart';
import 'package:beacon_project/models/resource.dart';
import 'package:beacon_project/models/device.dart';
import 'package:mockito/mockito.dart';
import '../mocks.mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/repositories/mock/mock_device_repository.dart';
import 'package:beacon_project/repositories/mock/mock_cluster_repository.dart';
import 'package:beacon_project/repositories/mock/mock_cluster_member_repository.dart';





void main() {

   setUp(() {
    SharedPreferences.setMockInitialValues({'dashboard_mode': 'initiator'});
  });
  group('ResourceViewModel', () {
    test('initial values are correct', () {
      final viewModel = ResourceViewModel();
      expect(viewModel.selectedTab, ResourceType.foodWater);
      expect(viewModel.resources, isEmpty);
      expect(viewModel.connectedDevices, isEmpty);
      expect(viewModel.isLoading, isFalse);
    });

    test('init sets variables correctly', () async {

      final beacon= MockNearbyConnectionsBase();

      final deviceRepo = MockDeviceRepository();
      final clusterRepo = MockClusterRepository();
      final clusterMemberRepo = MockClusterMemberRepository();
      when(beacon.deviceName).thenReturn('TestDevice');
      when(beacon.uuid).thenReturn('TestUUID');



      List<Resource> mockResources = [
        Resource(resourceId: '1',resourceName:"test1" , resourceType: ResourceType.foodWater, resourceDescription: "desc1", userUuid: "uuid1",resourceStatus: ResourceStatus.posted),
      ];

      List<Device> mockDevices = [
        Device(
          uuid: 'TestUUID',
          deviceName: 'TestDevice',
          endpointId: 'endpoint_1',
          status: 'connected',
          isOnline: true,
          inRange: true,
        ),
        Device(
          uuid: 'device_2_uuid',
          deviceName: 'TestDevice2',
          endpointId: 'endpoint_2',
          status: 'connected',
          isOnline: true,
          inRange: true,
        ),
      ];

    int notified =0;
  
      final viewModel = ResourceViewModel(nearbyConnections: beacon,repository: MockResourceRepository(mockDevices: mockDevices,mockResources: mockResources));
      viewModel.addListener(() {
        notified++;
      });
      await viewModel.init();
      
      expect(viewModel.beacon, isNotNull);
      expect(viewModel.beacon!.deviceName, 'TestDevice');
      expect(viewModel.beacon!.uuid, 'TestUUID');
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.resources, mockResources);
      expect(viewModel.connectedDevices, mockDevices);
      verify(beacon.init(deviceRepo,clusterRepo,clusterMemberRepo)).called(1);
      expect(notified, greaterThan(1));
      beacon.dispose();
      
    }); 


    test('changeTab updates selectedTab and notifies listeners', () {
      final viewModel = ResourceViewModel();
      int notified = 0;
      viewModel.addListener(() {
        notified++;
      });

      viewModel.changeTab(ResourceType.shelter);
      expect(viewModel.selectedTab, ResourceType.shelter);
      expect(notified, 1);
    });


    test('postResource adds a new resource and notifies listeners', () async {
      final mockRepository = MockResourceRepository(
        mockResources: [],
        mockDevices: [],
      );
      final beacon= MockNearbyConnectionsBase();
      when(beacon.uuid).thenReturn('TestUUID');

      final viewModel = ResourceViewModel(nearbyConnections: beacon,repository: mockRepository);

     await viewModel.init();

      int notified = 0;
      viewModel.addListener(() {
        notified++;
      });

      await viewModel.postResource('Water Bottle', 'A bottle of clean water');

      expect(viewModel.resources.length, 1);
      final addedResource = viewModel.resources.first;
      expect(addedResource.resourceName, 'Water Bottle');
      expect(addedResource.resourceDescription, 'A bottle of clean water');
      expect(addedResource.userUuid, 'TestUUID');
      expect(addedResource.resourceStatus, ResourceStatus.posted);
      expect(notified, greaterThan(1));
    });

    //need to test el cancel subscription 
    test('dispose cleans up listeners and subscriptions', () async {
      final beacon= MockNearbyConnectionsBase();
      final repository=MockResourceRepository(mockDevices: [], mockResources: []);
      final viewModel = ResourceViewModel(nearbyConnections: beacon,repository: repository);
      await viewModel.init();

      viewModel.dispose();

      verify(beacon.removeListener(any)).called(1);
    });

    test('requestResource updates resource status and notifies listeners', () async {
      final mockRepository = MockResourceRepository(
        mockResources: [
          Resource(
            resourceId: '1',
            resourceName: 'Food Pack',
            resourceType: ResourceType.foodWater,
            resourceDescription: 'A pack of food',
            userUuid: 'user_1',
            resourceStatus: ResourceStatus.posted,
          ),
        ],
        mockDevices: [],
      );
      final beacon=MockNearbyConnectionsBase();

      when(beacon.uuid).thenReturn('TestUUID');

      final viewModel = ResourceViewModel(nearbyConnections: beacon,repository: mockRepository);
      await viewModel.init();
      await viewModel.fetchResources();

      int notified = 0;
      viewModel.addListener(() {
        notified++;
      });

      await viewModel.requestResource('Cake', 'Please');

      final updatedResource = viewModel.resources.firstWhere((r) => r.resourceName == 'Cake');
      expect(updatedResource.resourceStatus, ResourceStatus.requested);
      expect(notified, greaterThan(0));
    });



    
  });
}

