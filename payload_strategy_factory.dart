import 'payload_strategy.dart';
import 'cluster_info_payload_strategy.dart';
import 'mark_offline_payload_strategy.dart';
import 'mark_online_payload_strategy.dart';
import 'nearby_connections.dart';
import 'chat_payload_strategy.dart';
import 'send_payload_strategy.dart';
import 'broadcast_payload_strategy.dart';

class PayloadStrategyFactory {
  static NearbyConnectionsBase? _beacon;

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
      case CHAT_MESSAGE:
      case CHAT_IMAGE:
        return ChatPayloadStrategy(_beacon!);
      case "SEND": // example of adding a new strategy
        return SendPayloadStrategy(_beacon!);
      case "BROADCAST":
        return BroadcastPayloadStrategy(_beacon!);
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
