import 'package:beacon_project/models/device.dart';

abstract class DeviceRepository {
  Future<Device?> getDeviceByUuid(String uuid);
  Future<List<Device>> getAllDevices();
  Future<List<Device>> getDevicesInRange();
  Future<List<Device>> getDevicesByUuids(List<String> uuids);
  Future<void> insertDevice(Device device);
  Future<void> updateDevice(Device device);
  Future<void> updateDeviceStatus(String uuid, String status);
  Future<void> markDeviceOnline(String uuid);
  Future<void> markDeviceOffline(String uuid);
  Future<void> updateDeviceInRange(String uuid, bool inRange);
  Future<void> updateDeviceEndpoint(String uuid, String endpointId);
  Future<void> deleteDevice(String uuid);
  Future<List<Device>> getDevicesNotInCluster(String clusterId, String excludeUuid);
}
