import 'package:beacon_project/models/cluster.dart';

import 'payload_strategy.dart';
import 'cluster_info_payload_strategy.dart';
import 'mark_offline_payload_strategy.dart';
import 'mark_online_payload_strategy.dart';
import 'nearby_connections.dart';
import 'resources_payload_strategy.dart';
import 'transfer_ownership_payload_strategy.dart';
import 'owner_changed_payload_strategy.dart';
import 'ownership_transferred_payload_strategy.dart';

import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';

import 'chat_message_payload_strategy.dart';
import 'package:beacon_project/repositories/chat_repository.dart';
import 'package:beacon_project/repositories/chat_message_repository.dart';

class PayloadStrategyFactory {
  // Store beacon instance for dependency injection
  static NearbyConnectionsBase? _beacon;
  static DeviceRepository? _deviceRepository;
  static ClusterRepository? _clusterRepository;
  static ClusterMemberRepository? _clusterMemberRepository;
  static ChatRepository? _chatRepository;
  static ChatMessageRepository? _chatMessageRepository;

  // Initialize factory with beacon instance
  static void initialize(
    NearbyConnectionsBase beacon,
    DeviceRepository deviceRepository,
    ClusterRepository clusterRepository,
    ClusterMemberRepository clusterMemberRepository,
    ChatRepository chatRepository,
    ChatMessageRepository chatMessageRepository,
  ) {
    _deviceRepository = deviceRepository;
    _clusterRepository = clusterRepository;
    _clusterMemberRepository = clusterMemberRepository;
    _chatRepository = chatRepository;
    _chatMessageRepository = chatMessageRepository;
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
        return MarkOfflinePayloadStrategy(_beacon!, _deviceRepository!);
      case "MARK_ONLINE":
        return MarkOnlinePayloadStrategy(_beacon!, _deviceRepository!);
      case "CLUSTER_INFO":
        return ClusterInfoPayloadStrategy(
          _beacon!,
          _deviceRepository!,
          _clusterMemberRepository!,
        );
      case "RESOURCES":
        return ResourcesPayloadStrategy();
      case "TRANSFER_OWNERSHIP":
        return TransferOwnershipPayloadStrategy(
          _beacon!,
          _deviceRepository!,
          _clusterRepository!,
          _clusterMemberRepository!,
        );
      case "OWNER_CHANGED":
        return OwnerChangedPayloadStrategy(
          _beacon!,
          _deviceRepository!,
          _clusterRepository!,
          _clusterMemberRepository!,
        );
      case "OWNERSHIP_TRANSFERRED":
        return OwnershipTransferredPayloadStrategy(_beacon!);
      case "CHAT_MESSAGE":
        return ChatMessagePayloadStrategy(
          _beacon!,
          _chatRepository!,
          _chatMessageRepository!,
        );

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
