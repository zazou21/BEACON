import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beacon_project/screens/chat_page.dart';
import 'package:beacon_project/models/chat.dart';
import 'package:beacon_project/models/device.dart';
import 'package:beacon_project/repositories/mock/mock_chat_repository.dart';
import 'package:beacon_project/repositories/mock/mock_device_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChatPage Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({
        'device_uuid': 'my_device_uuid',
      });
    });

    testWidgets('ChatPage renders and has back button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatPage(
            deviceUuid: 'device_uuid_1',
            isGroupChat: false,
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('ChatPage has app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatPage(
            deviceUuid: 'device_uuid_1',
            isGroupChat: false,
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('ChatPage displays message input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatPage(
            deviceUuid: 'device_uuid_1',
            isGroupChat: false,
          ),
        ),
      );

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('ChatPage displays send button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatPage(
            deviceUuid: 'device_uuid_1',
            isGroupChat: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.send), findsOneWidget);
    });


    testWidgets('ChatPage shows loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatPage(
            deviceUuid: 'device_uuid_1',
            isGroupChat: false,
          ),
        ),
      );

      // Should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
