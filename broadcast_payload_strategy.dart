import 'dart:convert';
import 'payload_strategy.dart';
import 'nearby_connections.dart';

class BroadcastPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;
  BroadcastPayloadStrategy(this.beacon);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    try {
      final message = data['message']?.toString() ?? '';
      print('[BroadcastPayload] broadcasting message: $message');

      final payload = {
        'type': 'BROADCAST',
        'message': message,
        'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
      };

      // send to all connected endpoints
      for (final epId in beacon.connectedEndpoints) {
        beacon.sendChatMessage(epId, jsonEncode(payload));
      }
    } catch (e) {
      print('[BroadcastPayload] handle error: $e');
    }
  }
}
