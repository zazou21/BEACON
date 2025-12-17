

part of 'resource_repository.dart';

/// Mock implementation of ResourceRepository for testing
class MockResourceRepository implements ResourceRepository {

  MockResourceRepository(
    {required this.mockResources, required this.mockDevices}
  );
  /// Mock resources for testing
  final List<Resource> mockResources;

  /// Mock devices for testing
  final List<Device> mockDevices;


  @override
  Future<List<Resource>> fetchResources() async {
    return mockResources;
  }

  @override
  Future<List<Device>> fetchConnectedDevices() async {
    return mockDevices;
  }

  @override
  Future<void> insertResource(Resource resource) async {
    mockResources.add(resource);
  }
}
