import 'dart:convert';
import 'dart:typed_data';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/services/nearby_connections/payload_strategy.dart';

/// Payload types used for chat
const String CHAT_MESSAGE = "CHAT_MESSAGE";
const String CHAT_IMAGE = "CHAT_IMAGE";

class ChatPayloadStrategy implements PayloadStrategy {
  final NearbyConnectionsBase beacon;

  ChatPayloadStrategy(this.beacon);

  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    try {
      // If data contains 'text' => it's a chat text
      if (data.containsKey('text')) {
        final text = data['text']?.toString() ?? '';
        if (text.isNotEmpty) {
          // forward to any UI callback
          if (beacon.onChatMessageReceived != null) {
            beacon.onChatMessageReceived!(endpointId, text);
          }
        }
        return;
      }

      // If data contains 'bytes' (base64) -> treat as image
      if (data.containsKey('bytes')) {
        final bytesValue = data['bytes'];
        // if bytesValue is already a List<int> or Uint8List, handle directly
        if (bytesValue is List) {
          final Uint8List bytes = Uint8List.fromList(
            List<int>.from(bytesValue),
          );
          beacon.onChatImageReceived?.call(endpointId, bytes);
          return;
        }
        // if bytesValue is base64 string
        if (bytesValue is String) {
          try {
            final decoded = base64Decode(bytesValue);
            beacon.onChatImageReceived?.call(
              endpointId,
              Uint8List.fromList(decoded),
            );
            return;
          } catch (_) {
            // ignore decode error
          }
        }
      }

      // Unknown chat payload shape
      print(
        "[ChatPayloadStrategy] unknown chat payload shape from $endpointId: $data",
      );
    } catch (e) {
      print("[ChatPayloadStrategy] handle error: $e");
    }
  }
}
