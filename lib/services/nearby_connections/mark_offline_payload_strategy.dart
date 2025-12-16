// lib/services/nearby_connections/strategies/mark_offline_payload_strategy.dart
import 'package:beacon_project/repositories/device_repository.dart';
import 'payload_strategy.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';

class MarkOfflinePayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  final DeviceRepository deviceRepository;

  MarkOfflinePayloadStrategy(this.beacon, this.deviceRepository);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("[Handling MARK_OFFLINE payload] for uuid: ${data['uuid']}");
    
    final deviceUuid = data['uuid'] as String?;
    if (deviceUuid == null) {
      print("Error: deviceUuid is null in MARK_OFFLINE payload");
      return;
    }

    try {
      final existing = await deviceRepository.getDeviceByUuid(deviceUuid);
      
      if (existing == null) {
        print("Warning: Device $deviceUuid not found in database");
        return;
      }

      await deviceRepository.markDeviceOffline(deviceUuid);
      print("Device $deviceUuid marked as offline in database");
      
      beacon.notifyListeners();
    } catch (e) {
      print("Error handling MARK_OFFLINE payload: $e");
    }
  }
}
