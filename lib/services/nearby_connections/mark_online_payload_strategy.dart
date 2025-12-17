// lib/services/nearby_connections/strategies/mark_online_payload_strategy.dart
import 'payload_strategy.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';

class MarkOnlinePayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  final DeviceRepository deviceRepository;

  MarkOnlinePayloadStrategy(this.beacon, this.deviceRepository);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("[Handling MARK_ONLINE payload] for endpointId: $endpointId");
    
    final deviceUuid = data['uuid'] as String?;
    if (deviceUuid == null) {
      print("Error: deviceUuid is null in MARK_ONLINE payload");
      return;
    }

    try {
      final existing = await deviceRepository.getDeviceByUuid(deviceUuid);
      
      if (existing == null) {
        print("Warning: Device $deviceUuid not found in database");
        return;
      }

      await deviceRepository.markDeviceOnline(deviceUuid);
      print("Device $deviceUuid marked as online in database");
      
      beacon.notifyListeners();
    } catch (e) {
      print("Error handling MARK_ONLINE payload: $e");
    }
  }
}
