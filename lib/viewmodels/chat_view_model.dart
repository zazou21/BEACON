import 'package:flutter/foundation.dart';
import 'package:beacon_project/models/chat.dart';
import 'package:beacon_project/models/chat_message.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/repositories/chat_repository.dart';
import 'package:beacon_project/repositories/chat_message_repository.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _chatRepository;
  final ChatMessageRepository _chatMessageRepository;
  final DeviceRepository _deviceRepository;
  final NearbyConnectionsBase _nearby;
  final String _deviceUuid;

  Chat? _chat;
  Device? _device;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _myUuid;
  StreamSubscription? _messageRefreshSubscription;

  ChatViewModel({
    required ChatRepository chatRepository,
    required ChatMessageRepository chatMessageRepository,
    required DeviceRepository deviceRepository,
    required NearbyConnectionsBase nearby,
    required String deviceUuid,
  }) : _chatRepository = chatRepository,
       _chatMessageRepository = chatMessageRepository,
       _deviceRepository = deviceRepository,
       _nearby = nearby,
       _deviceUuid = deviceUuid {
    _initialize();
    // Listen to nearby connection state changes
    _nearby.addListener(_onNearbyStateChanged);
  }

  Chat? get chat => _chat;
  Device? get device => _device;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get myUuid => _myUuid;

  void _onNearbyStateChanged() {
    // Refresh device status and messages when nearby state changes
    _refreshDeviceStatus();
    refreshMessages();
  }

  Future<void> _refreshDeviceStatus() async {
    try {
      final updatedDevice = await _deviceRepository.getDeviceByUuid(
        _deviceUuid,
      );
      if (updatedDevice != null) {
        _device = updatedDevice;
        notifyListeners();
      }
    } catch (e) {
      print("[ChatViewModel] Error refreshing device status: $e");
    }
  }

  Future<String> _getDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString('device_uuid');
    if (stored == null) {
      stored = const Uuid().v4();
      await prefs.setString('device_uuid', stored);
    }
    return stored;
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get my UUID from SharedPreferences
      _myUuid = await _getDeviceUUID();

      // Load device info
      _device = await _deviceRepository.getDeviceByUuid(_deviceUuid);

      if (_device == null) {
        print("[ChatViewModel] Device not found");
        return;
      }

      // Generate chat ID (same for both users)
      String chatId = _generateChatId(_myUuid!, _deviceUuid);

      // Get or create chat
      _chat = await _chatRepository.getChatById(chatId);

      if (_chat == null) {
        _chat = Chat(id: chatId, deviceUuid: _deviceUuid);
        await _chatRepository.insertChat(_chat!);
      }

      // Load messages
      await refreshMessages();

      // Start periodic refresh for messages only
      _startMessageRefresh();
    } catch (e) {
      print("[ChatViewModel] Error initializing: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startMessageRefresh() {
    // Refresh messages every 2 seconds to catch incoming messages
    _messageRefreshSubscription = Stream.periodic(
      const Duration(seconds: 2),
    ).listen((_) => refreshMessages());
  }

  // Generate same chat ID for both users
  String _generateChatId(String uuid1, String uuid2) {
    List<String> uuids = [uuid1, uuid2];
    uuids.sort(); // Sort to ensure same order
    return '${uuids[0]}_${uuids[1]}';
  }

  Future<void> sendMessage(String messageText) async {
    if (_chat == null ||
        _device == null ||
        messageText.trim().isEmpty ||
        _myUuid == null)
      return;

    final messageId = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Create message
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
      // Send via Nearby Connections
      await _nearby.sendChatMessage(
        _device!.endpointId,
        messageId,
        _chat!.id,
        messageText.trim(),
        timestamp,
      );

      // Save to database
      await _chatMessageRepository.insertMessage(message);
    } catch (e) {
      print("[ChatViewModel] Error sending message: $e");
      // Remove failed message
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

    if (_device!.isOnline) {
      return 'Online';
    }

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
