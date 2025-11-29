import 'dart:convert';
import 'payload_strategy.dart';
import 'nearby_connections.dart';

class SendPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  SendPayloadStrategy(this.beacon);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    // This is an example of a custom "SEND" message handler that simply
    // echoes or transforms the payload and replies using sendChatMessage.
    try {
      final message = data['message']?.toString() ?? '';
      print('[SendPayload] Received SEND from $endpointId: $message');

      // Example: reply ACK back to sender
      final ack = {
        'status': 'ACK',
        'receivedMessage': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Use your existing sendChatMessage helper to send the payload back
      beacon.sendChatMessage(
        endpointId,
        jsonEncode({'type': 'SEND_ACK', 'data': ack}),
      );
    } catch (e) {
      print('[SendPayload] handle error: $e');
    }
  }
}
