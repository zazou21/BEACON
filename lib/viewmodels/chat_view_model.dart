import 'package:beacon_project/repositories/chat_repository_impl.dart';
import 'package:beacon_project/repositories/chat_message_repository_impl.dart';
import 'package:beacon_project/repositories/device_repository_impl.dart';
import 'package:beacon_project/repositories/cluster_repository_impl.dart';
import 'package:beacon_project/repositories/cluster_member_repository_impl.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:flutter/foundation.dart';
import 'package:beacon_project/models/chat.dart';
import 'package:beacon_project/models/chat_message.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/models/cluster.dart';
import 'package:beacon_project/models/cluster_member.dart';
import 'package:beacon_project/repositories/chat_repository.dart';
import 'package:beacon_project/repositories/chat_message_repository.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class ChatViewModel extends ChangeNotifier {
  late final ChatRepository _chatRepository;
  late final ChatMessageRepository _chatMessageRepository;
  late final DeviceRepository _deviceRepository;
  late final ClusterRepository _clusterRepository;
  late final ClusterMemberRepository _clusterMemberRepository;
  late final NearbyConnectionsBase _nearby;

  final String? _deviceUuid;
  final String? _clusterId;
  final bool isGroupChat;

  Chat? _chat;
  Device? _device;
  Cluster? _cluster;
  List<ChatMessage> _messages = [];
  List<ClusterMember> _clusterMembers = [];
  Map<String, Device> _memberDevices = {};
  bool _isLoading = false;
  String? _myUuid;
  StreamSubscription? _messageRefreshSubscription;

  ChatViewModel({
    ChatRepository? chatRepository,
    ChatMessageRepository? chatMessageRepository,
    DeviceRepository? deviceRepository,
    ClusterRepository? clusterRepository,
    ClusterMemberRepository? clusterMemberRepository,
    String? deviceUuid,
    String? clusterId,
    this.isGroupChat = false,
  })  : _deviceUuid = deviceUuid,
        _clusterId = clusterId {
    // Initialize repositories with provided instances or create defaults
    final dbService = DBService();
    _chatRepository = chatRepository ?? ChatRepositoryImpl(dbService);
    _chatMessageRepository =
        chatMessageRepository ?? ChatMessageRepositoryImpl(dbService);
    _deviceRepository = deviceRepository ?? DeviceRepositoryImpl(dbService);
    _clusterRepository = clusterRepository ?? ClusterRepositoryImpl(dbService);
    _clusterMemberRepository =
        clusterMemberRepository ?? ClusterMemberRepositoryImpl(dbService);

    // Initialize nearby connection based on saved mode
    _initializeNearby();
  }

  // Initialize nearby connection from singleton based on saved mode
  Future<void> _initializeNearby() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('dashboard_mode') ?? 'joiner';
      final isInitiator = modeStr == 'initiator';

      _nearby = isInitiator
          ? NearbyConnectionsInitiator()
          : NearbyConnectionsJoiner();

      _nearby.addListener(_onNearbyStateChanged);

      print('[ChatViewModel] Initialized nearby: ${_nearby.runtimeType}');
      print('[ChatViewModel] Connected endpoints: ${_nearby.connectedEndpoints.length}');
      print('[ChatViewModel] Device UUID: ${_nearby.uuid}');

      // Start initialization after nearby is set
      _initialize();
    } catch (e) {
      print('[ChatViewModel] Error initializing nearby: $e');
    }
  }

  Chat? get chat => _chat;
  Device? get device => _device;
  Cluster? get cluster => _cluster;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get myUuid => _myUuid;
  int get clusterMemberCount => _clusterMembers.length;

  void _onNearbyStateChanged() {
    if (!isGroupChat) {
      _refreshDeviceStatus();
    } else {
      _refreshClusterMembers();
    }
    refreshMessages();
  }

  Future<void> _refreshDeviceStatus() async {
    if (_deviceUuid == null) return;
    try {
      final updatedDevice = await _deviceRepository.getDeviceByUuid(
        _deviceUuid!,
      );
      if (updatedDevice != null) {
        _device = updatedDevice;
        notifyListeners();
      }
    } catch (e) {
      print("[ChatViewModel] Error refreshing device status: $e");
    }
  }

  Future<void> _refreshClusterMembers() async {
    if (_clusterId == null) return;
    try {
      _clusterMembers = await _clusterMemberRepository.getMembersByClusterId(
        _clusterId!,
      );
      // Load device info for all members
      for (var member in _clusterMembers) {
        if (!_memberDevices.containsKey(member.deviceUuid)) {
          final device = await _deviceRepository.getDeviceByUuid(
            member.deviceUuid,
          );
          if (device != null) {
            _memberDevices[member.deviceUuid] = device;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      print("[ChatViewModel] Error refreshing cluster members: $e");
    }
  }

  Future<String> _getDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString('device_uuid');
    if (stored == null) {
      stored = const Uuid().v4();
      await prefs.setString('device_uuid', stored);
    }
    print("Device UUID: $stored");
    return stored;
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _myUuid = await _getDeviceUUID();

      if (isGroupChat) {
        await _initializeGroupChat();
      } else {
        await _initializePrivateChat();
      }

      _messages = await _chatMessageRepository.getMessagesByChatId(_chat!.id);
      _startMessageRefresh();
    } catch (e) {
      print("[ChatViewModel] Error initializing: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeGroupChat() async {
    if (_clusterId == null) {
      print("[ChatViewModel] Cluster ID is null for group chat");
      return;
    }

    // Load cluster info
    _cluster = await _clusterRepository.getClusterById(_clusterId!);
    if (_cluster == null) {
      print("[ChatViewModel] Cluster not found");
      return;
    }

    // Load cluster members
    await _refreshClusterMembers();

    // Get or create group chat
    final chatRepository = _chatRepository as ChatRepositoryImpl;
    _chat = await chatRepository.getChatByClusterId(_clusterId!);
    if (_chat == null) {
      _chat = Chat(
        id: 'group_$_clusterId',
        clusterId: _clusterId,
        isGroupChat: true,
      );
      await _chatRepository.insertChat(_chat!);
    }
  }

  Future<void> _initializePrivateChat() async {
    if (_deviceUuid == null) {
      print("[ChatViewModel] Device UUID is null for private chat");
      return;
    }

    // Load device info
    _device = await _deviceRepository.getDeviceByUuid(_deviceUuid!);
    if (_device == null) {
      print("[ChatViewModel] Device not found");
      return;
    }

    // Generate chat ID (same for both users)
    String chatId = _generateChatId(_myUuid!, _deviceUuid!);

    // Get or create chat
    _chat = await _chatRepository.getChatById(chatId);
    if (_chat == null) {
      _chat = Chat(id: chatId, deviceUuid: _deviceUuid, isGroupChat: false);
      await _chatRepository.insertChat(_chat!);
    }
  }

  void _startMessageRefresh() {
    _messageRefreshSubscription = Stream.periodic(
      const Duration(seconds: 2),
    ).listen((_) => refreshMessages());
  }

  String _generateChatId(String uuid1, String uuid2) {
    List<String> uuids = [uuid1, uuid2];
    uuids.sort();
    return '${uuids[0]}_${uuids[1]}';
  }

  Future<void> sendMessage(String messageText) async {
    if (_chat == null || messageText.trim().isEmpty || _myUuid == null) return;

    final messageId = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final message = ChatMessage(
      id: messageId,
      chatId: _chat!.id,
      senderUuid: _myUuid!,
      messageText: messageText.trim(),
      timestamp: timestamp,
    );

    // Add to local list immediately
    _messages.add(message);
    notifyListeners();

    try {
      if (isGroupChat) {
        // Send to all cluster members via broadcast
        await _nearby.broadcastChatMessage(
          messageId,
          _chat!.id,
          messageText.trim(),
          timestamp,
        );
      } else {
        // Send to specific device
        if (_device == null) {
          throw Exception("Device not found for private message");
        }

        await _nearby.sendChatMessage(
          _device!.endpointId,
          messageId,
          _chat!.id,
          messageText.trim(),
          timestamp,
        );
      }

      // Save to database
      await _chatMessageRepository.insertMessage(message);
    } catch (e) {
      print("[ChatViewModel] Error sending message: $e");
      _messages.removeLast();
      notifyListeners();
    }
  }

  Future<void> refreshMessages() async {
    if (_chat == null) return;
    try {
      final newMessages = await _chatMessageRepository.getMessagesByChatId(
        _chat!.id,
      );
      if (newMessages.length != _messages.length) {
        _messages = newMessages;
        notifyListeners();
      }
    } catch (e) {
      print("[ChatViewModel] Error refreshing messages: $e");
    }
  }

  String getSenderName(String senderUuid) {
    if (senderUuid == _myUuid) return 'You';
    final device = _memberDevices[senderUuid];
    return device?.deviceName ?? 'Unknown';
  }

  String formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String getLastSeenText() {
    if (_device == null) return '';
    if (_device!.isOnline) return 'Online';

    final now = DateTime.now();
    final diff = now.difference(_device!.lastSeen);

    if (diff.inSeconds < 60) {
      return 'Last seen just now';
    } else if (diff.inMinutes < 60) {
      return 'Last seen ${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return 'Last seen ${diff.inHours} hours ago';
    } else {
      return 'Last seen ${diff.inDays} days ago';
    }
  }

  @override
  void dispose() {
    _messageRefreshSubscription?.cancel();
    _nearby.removeListener(_onNearbyStateChanged);
    super.dispose();
  }
}
