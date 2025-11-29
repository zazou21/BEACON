import 'payload_strategy.dart';
import 'cluster_info_payload_strategy.dart';
import 'mark_offline_payload_strategy.dart';
import 'mark_online_payload_strategy.dart';
import 'nearby_connections.dart';

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
      default:
        return UnknownPayloadStrategy();
    }
  }
}

// Fallback for unknown message types
class UnknownPayloadStrategy implements PayloadStrategy {
  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("Unknown payload type received from $endpointId");
  }
}
