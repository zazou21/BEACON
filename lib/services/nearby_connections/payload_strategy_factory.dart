import 'payload_strategy.dart';
import 'handshake_payload_strategy.dart';

class PayloadStrategyFactory {
  static PayloadStrategy getHandler(String data) {
    if (data.startsWith("HANDSHAKE:")) {
      return HandshakePayloadStrategy();
    }

    // Fallback (optional)
    return _EmptyPayloadStrategy();
  }
}

class _EmptyPayloadStrategy implements PayloadStrategy {
  @override
  void handle(String data, String endpointId) {
    print("No matching payload strategy for: $data");
  }
}
