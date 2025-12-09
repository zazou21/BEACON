import 'payload_strategy.dart';
import 'nearby_connections.dart';

class OwnershipTransferredPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;

  OwnershipTransferredPayloadStrategy(this.beacon);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print('[Payload] Ownership successfully transferred');
    
    final clusterId = data['clusterId'] as String;
    final newOwnerUuid = data['newOwnerUuid'] as String;
    
    print('[Payload] Cluster $clusterId now owned by $newOwnerUuid');
    
    // Old owner can now safely disconnect
    beacon.notifyListeners();
  }
}
