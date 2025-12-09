import 'payload_strategy.dart';
import 'cluster_info_payload_strategy.dart';
import 'mark_offline_payload_strategy.dart';
import 'mark_online_payload_strategy.dart';
import 'nearby_connections.dart';
import 'resources_payload_strategy.dart';
import 'transfer_ownership_payload_strategy.dart';
import 'owner_changed_payload_strategy.dart';
import 'ownership_transferred_payload_strategy.dart';


class PayloadStrategyFactory {
  // Store beacon instance for dependency injection
  static NearbyConnectionsBase? _beacon;

  // Initialize factory with beacon instance
  static void initialize(NearbyConnectionsBase beacon) {
    _beacon = beacon;
  }

  static PayloadStrategy getHandler(String type) {
    if (_beacon == null) {
      throw StateError(
        'PayloadStrategyFactory not initialized. Call initialize() first.',
      );
    }

    switch (type) {
      case "MARK_OFFLINE":
        return MarkOfflinePayloadStrategy(_beacon!);
      case "MARK_ONLINE":
        return MarkOnlinePayloadStrategy(_beacon!);
      case "CLUSTER_INFO":
        return ClusterInfoPayloadStrategy(_beacon!);
      case "RESOURCES":
        return ResourcesPayloadStrategy();
      case "TRANSFER_OWNERSHIP":
        return TransferOwnershipPayloadStrategy(_beacon!);
      case "OWNER_CHANGED":
        return OwnerChangedPayloadStrategy(_beacon!);
      case "OWNERSHIP_TRANSFERRED":
        return OwnershipTransferredPayloadStrategy(_beacon!);

      

      default:
        return UnknownPayloadStrategy();
    }
  }
}

class UnknownPayloadStrategy implements PayloadStrategy {
  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("Unknown payload type received from $endpointId");
  }
}
