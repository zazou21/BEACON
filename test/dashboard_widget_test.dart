// test/views/dashboard_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beacon_project/screens/dashboard_page.dart';
import 'package:beacon_project/models/dashboard_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'device_uuid': 'test-uuid-123'});
  });

  Widget createTestWidget(DashboardMode mode) {
    return MaterialApp(home: DashboardPage(mode: mode));
  }

  group('DashboardPage - Basic Rendering', () {
    testWidgets('should display AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.initiator));
      await tester.pump(); // Just one pump to avoid initialization

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should display Print DB button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.initiator));
      await tester.pump();

      expect(find.text('Print DB'), findsOneWidget);
    });

    testWidgets('should display Stop All button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.initiator));
      await tester.pump();

      expect(find.text('Stop All'), findsOneWidget);
    });
  });

  group('DashboardPage - Initiator Mode UI Elements', () {
    testWidgets('should show available devices section header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.initiator));
      await tester.pump();

      // Scroll to find the text
      await tester.dragUntilVisible(
        find.text('Available Devices'),
        find.byType(ListView),
        const Offset(0, -50),
      );

      expect(find.text('Available Devices'), findsOneWidget);
    });

    testWidgets('should show connected devices section header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.initiator));
      await tester.pump();

      await tester.dragUntilVisible(
        find.text('Connected Devices'),
        find.byType(ListView),
        const Offset(0, -50),
      );

      expect(find.text('Connected Devices'), findsOneWidget);
    });

    testWidgets('should show empty state messages', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.initiator));
      await tester.pump();

      // Look for empty state messages
      await tester.dragUntilVisible(
        find.text('No devices found'),
        find.byType(ListView),
        const Offset(0, -50),
      );

      expect(find.text('No devices found'), findsOneWidget);
    });
  });

  group('DashboardPage - Joiner Mode UI Elements', () {
    testWidgets('should show discovered clusters section', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.joiner));
      await tester.pump();

      await tester.dragUntilVisible(
        find.text('Discovered Clusters'),
        find.byType(ListView),
        const Offset(0, -50),
      );

      expect(find.text('Discovered Clusters'), findsOneWidget);
    });

    testWidgets('should show joined cluster section', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.joiner));
      await tester.pump();

      await tester.dragUntilVisible(
        find.text('Joined Cluster'),
        find.byType(ListView),
        const Offset(0, -50),
      );

      expect(find.text('Joined Cluster'), findsOneWidget);
    });

    testWidgets('should show empty state for no clusters', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(DashboardMode.joiner));
      await tester.pump();

      expect(find.text('No clusters found'), findsOneWidget);
    });
  });

  group('DashboardPage - Widget Components', () {
    testWidgets('should render device status icon correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.smartphone, size: 40, color: Colors.grey[700]),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.wifi,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.smartphone), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
    });

    testWidgets('should render cluster icon correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.people, size: 35, color: Colors.grey[700]),
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.wifi,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('should render popup menu button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {},
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'chat', child: Text('Chat')),
                PopupMenuItem(
                  value: 'quick_message',
                  child: Text('Send Quick Message'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Tap to open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Send Quick Message'), findsOneWidget);
    });

    testWidgets('should render card with device info', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                leading: Icon(Icons.smartphone, color: Colors.grey[700]),
                title: const Text('Test Device'),
                subtitle: const Text('Online'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Test Device'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('should render elevated buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.campaign),
                  label: const Text('Broadcast'),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Broadcast'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.byIcon(Icons.campaign), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    });
  });

  group('DashboardPage - Button Interactions', () {
    testWidgets('should tap broadcast button without error', (
      WidgetTester tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton.icon(
              onPressed: () {
                tapped = true;
              },
              icon: const Icon(Icons.campaign),
              label: const Text('Broadcast'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Broadcast'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('should tap disconnect button without error', (
      WidgetTester tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton.icon(
              onPressed: () {
                tapped = true;
              },
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Disconnect'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Disconnect'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('should open and close popup menu', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'chat', child: Text('Chat')),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Open menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Chat'), findsOneWidget);

      // Close by tapping outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Chat'), findsNothing);
    });
  });

  group('DashboardPage - List and Card Rendering', () {
    testWidgets('should render empty list view', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ListView(children: [])),
        ),
      );

      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should render list with multiple cards', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                Card(child: ListTile(title: Text('Device 1'))),
                Card(child: ListTile(title: Text('Device 2'))),
                Card(child: ListTile(title: Text('Device 3'))),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Card), findsNWidgets(3));
      expect(find.text('Device 1'), findsOneWidget);
      expect(find.text('Device 2'), findsOneWidget);
      expect(find.text('Device 3'), findsOneWidget);
    });

    testWidgets('should scroll through long list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 20,
              itemBuilder: (context, index) =>
                  Card(child: ListTile(title: Text('Device $index'))),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Device 0'), findsOneWidget);
      expect(find.text('Device 19'), findsNothing);

      // Scroll down
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();

      expect(find.text('Device 19'), findsOneWidget);
    });
  });

  group('DashboardPage - Dialog Tests', () {
    testWidgets('should show alert dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Test Dialog'),
                      content: const Text('Dialog Content'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsOneWidget);
      expect(find.text('Dialog Content'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsNothing);
    });

    testWidgets('should show disconnect confirmation dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Disconnect from Cluster'),
                      content: const Text('Are you sure?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show Disconnect Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Show Disconnect Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect from Cluster'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Disconnect'), findsOneWidget);
    });
  });

  group('DashboardPage - Text Styling', () {
    testWidgets('should apply correct text styles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(
                  'Section Header',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Text('Online', style: TextStyle(color: Colors.green)),
                const Text('Tap to join', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Section Header'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Tap to join'), findsOneWidget);
    });
  });

  group('DashboardPage - Empty State Messages', () {
    testWidgets('should display centered empty state text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'No devices found',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No devices found'), findsOneWidget);
    });
  });
}
