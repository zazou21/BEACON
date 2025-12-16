// lib/repositories/mock/mock_device_repository.dart
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/models/device.dart';

class MockDeviceRepository implements DeviceRepository {
  final Map<String, Device> _devices = {};

  @override
  Future<Device?> getDeviceByUuid(String uuid) async {
    return _devices[uuid];
  }

  @override
  Future<List<Device>> getAllDevices() async {
    return _devices.values.toList();
  }

  @override
  Future<List<Device>> getDevicesInRange() async {
    return _devices.values.where((d) => d.inRange).toList();
  }

  @override
  Future<List<Device>> getDevicesByUuids(List<String> uuids) async {
    return uuids
        .map((uuid) => _devices[uuid])
        .where((device) => device != null)
        .cast<Device>()
        .toList();
  }

  @override
  Future<void> insertDevice(Device device) async {
    _devices[device.uuid] = device;
  }

  @override
  Future<void> updateDevice(Device device) async {
    _devices[device.uuid] = device;
  }

  @override
  Future<void> updateDeviceStatus(String uuid, String status) async {
    final device = _devices[uuid];
    if (device != null) {
      _devices[uuid] = Device(
        uuid: device.uuid,
        deviceName: device.deviceName,
        endpointId: device.endpointId,
        status: status,
        isOnline: device.isOnline,
        inRange: device.inRange,
        lastSeen: DateTime.now(),
        lastMessage: device.lastMessage,
        createdAt: device.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> markDeviceOnline(String uuid) async {
    final device = _devices[uuid];
    if (device != null) {
      _devices[uuid] = Device(
        uuid: device.uuid,
        deviceName: device.deviceName,
        endpointId: device.endpointId,
        status: device.status,
        isOnline: true,
        inRange: device.inRange,
        lastSeen: DateTime.now(),
        lastMessage: device.lastMessage,
        createdAt: device.createdAt,
        updatedAt: device.updatedAt,
      );
    }
  }

  @override
  Future<void> markDeviceOffline(String uuid) async {
    final device = _devices[uuid];
    if (device != null) {
      _devices[uuid] = Device(
        uuid: device.uuid,
        deviceName: device.deviceName,
        endpointId: device.endpointId,
        status: device.status,
        isOnline: false,
        inRange: device.inRange,
        lastSeen: DateTime.now(),
        lastMessage: device.lastMessage,
        createdAt: device.createdAt,
        updatedAt: device.updatedAt,
      );
    }
  }

  @override
  Future<void> updateDeviceInRange(String uuid, bool inRange) async {
    final device = _devices[uuid];
    if (device != null) {
      _devices[uuid] = Device(
        uuid: device.uuid,
        deviceName: device.deviceName,
        endpointId: device.endpointId,
        status: device.status,
        isOnline: device.isOnline,
        inRange: inRange,
        lastSeen: DateTime.now(),
        lastMessage: device.lastMessage,
        createdAt: device.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> updateDeviceEndpoint(String uuid, String endpointId) async {
    final device = _devices[uuid];
    if (device != null) {
      _devices[uuid] = Device(
        uuid: device.uuid,
        deviceName: device.deviceName,
        endpointId: endpointId,
        status: device.status,
        isOnline: device.isOnline,
        inRange: device.inRange,
        lastSeen: device.lastSeen,
        lastMessage: device.lastMessage,
        createdAt: device.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> deleteDevice(String uuid) async {
    _devices.remove(uuid);
  }

  @override
  Future<List<Device>> getDevicesNotInCluster(String clusterId, String excludeUuid) async {
    // This would require cluster member data in a real implementation
    // For mock, return all devices except excluded one
    return _devices.values
        .where((d) => d.uuid != excludeUuid && d.inRange)
        .toList();
  }

  // Helper method for testing
  void clear() {
    _devices.clear();
  }
}
