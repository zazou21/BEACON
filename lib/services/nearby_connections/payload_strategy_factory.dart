import 'payload_strategy.dart';
import 'cluster_info_payload_strategy.dart';
import 'resources_payload_strategy.dart';

class PayloadStrategyFactory {
  static PayloadStrategy getHandler(String type) {
    switch (type) {
      case "CLUSTER_INFO":
        return ClusterInfoPayloadStrategy();

      case "RESOURCES":
        return ResourcesPayloadStrategy();
      

      // add more types here
      // case "PING": return PingPayloadStrategy();
      // case "CHAT": return ChatPayloadStrategy();

      default:
        return _EmptyPayloadStrategy();
    }
  }
}

class _EmptyPayloadStrategy implements PayloadStrategy {
  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    print("No handler for message type '${data['type']}'");
  }
}
