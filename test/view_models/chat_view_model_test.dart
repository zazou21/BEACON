import 'package:flutter_test/flutter_test.dart';
import 'package:beacon_project/viewmodels/chat_view_model.dart';
import 'package:beacon_project/models/chat.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/repositories/mock/mock_chat_repository.dart';
import 'package:beacon_project/repositories/mock/mock_device_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ChatViewModel Tests', () {
    late ChatViewModel viewModel;
    late MockChatRepository mockChatRepository;
    late MockDeviceRepository mockDeviceRepository;
    late MockNearbyConnectionsBase mockNearby;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({
        'device_uuid': 'my_device_uuid',
      });

      // Setup mock repositories
      mockChatRepository = MockChatRepository(
        mockChats: [
          Chat(
            id: 'chat_1',
            deviceUuid: 'device_uuid_1',
            isGroupChat: false,
          ),
        ],
      );

      mockDeviceRepository = MockDeviceRepository();
      mockDeviceRepository.insertDevice(
        Device(
          uuid: 'device_uuid_1',
          deviceName: 'Test Device',
          endpointId: 'endpoint_1',
          status: 'connected',
        ),
      );

      // Create mock nearby connections using mockito
      mockNearby = MockNearbyConnectionsBase();
    });

    test('ChatViewModel initializes with device uuid for private chat', () {
      viewModel = ChatViewModel(
        chatRepository: mockChatRepository,
        deviceRepository: mockDeviceRepository,
        
        deviceUuid: 'device_uuid_1',
        isGroupChat: false,
      );

      expect(viewModel.isGroupChat, false);
    });

    test('ChatViewModel loads chat for private chat mode', () async {
      viewModel = ChatViewModel(
        chatRepository: mockChatRepository,
        deviceRepository: mockDeviceRepository,
      
        deviceUuid: 'device_uuid_1',
        isGroupChat: false,
      );

      // Wait for async initialization to complete
      await Future.delayed(const Duration(milliseconds: 200));

      expect(viewModel.chat, isNotNull);
      expect(viewModel.chat?.deviceUuid, 'device_uuid_1');
    });

    test('ChatViewModel loads device info for private chat', () async {
      viewModel = ChatViewModel(
        chatRepository: mockChatRepository,
        deviceRepository: mockDeviceRepository,
      
        deviceUuid: 'device_uuid_1',
        isGroupChat: false,
      );

      // Wait for async initialization
      await Future.delayed(const Duration(milliseconds: 200));

      expect(viewModel.device, isNotNull);
      expect(viewModel.device?.deviceName, 'Test Device');
    });

    test('ChatViewModel handles null device gracefully', () async {
      viewModel = ChatViewModel(
        chatRepository: mockChatRepository,
        deviceRepository: mockDeviceRepository,
        deviceUuid: 'nonexistent_uuid',
        isGroupChat: false,
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 200));

      // Should not throw
      expect(viewModel.device, isNull);
    });

    tearDown(() async {
      // Wait a bit before disposing to allow async operations to finish
      await Future.delayed(const Duration(milliseconds: 100));
      viewModel.dispose();
    });
  });
}
