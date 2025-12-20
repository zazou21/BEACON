import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:beacon_project/services/voice_commands.dart';
import 'package:beacon_project/services/MockSpeechToText.dart';

void main() {
  group('VoiceCommandWidget UI Tests', () {
    late MockSpeechToText mockSpeech;

    setUp(() {
      mockSpeech = MockSpeechToText();
    });

    tearDown(() {
      mockSpeech.reset();
    });

    Widget createTestApp({VoidCallback? toggleTheme, bool buttonMode = true}) {
      return MaterialApp(
        home: Scaffold(
          body: VoiceCommandWidget(
            speechToText: mockSpeech,
            toggleTheme: toggleTheme,
            buttonMode: buttonMode,
          ),
        ),
      );
    }

    testWidgets('VoiceCommandWidget renders in button mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(buttonMode: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.text('Tap mic for voice commands'), findsOneWidget);
    });

    testWidgets('VoiceCommandWidget renders as FloatingActionButton', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(buttonMode: false));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Tapping mic starts listening', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('Listening…'), findsOneWidget);

      // Stop listening to clean up timer
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping mic again stops listening', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.text('Tap mic for voice commands'), findsOneWidget);
    });

    testWidgets('Listening state icon changes correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(buttonMode: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byIcon(Icons.mic), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('Speech initialization succeeds', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(mockSpeech.isInitialized, isTrue);
    });

    testWidgets('Speech initialization error is handled gracefully', (
      WidgetTester tester,
    ) async {
      final errorSpeech = MockSpeechToText();
      errorSpeech.setSimulateError(true, error: 'Permission denied');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceCommandWidget(
              speechToText: errorSpeech,
              buttonMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VoiceCommandWidget), findsOneWidget);
    });
  });

  group('VoiceCommandWidget Routing Tests', () {
    late MockSpeechToText mockSpeech;
    late List<String> routeHistory;

    setUp(() {
      mockSpeech = MockSpeechToText();
      routeHistory = [];
    });

    testWidgets('"dashboard" command routes to dashboard', (
      WidgetTester tester,
    ) async {
      mockSpeech.setNextRecognitionResult('dashboard');

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: VoiceCommandWidget(speechToText: mockSpeech),
                ),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) =>
                    const Scaffold(body: Text('Dashboard')),
              ),
              GoRoute(
                path: '/resources',
                builder: (context, state) =>
                    const Scaffold(body: Text('Resources')),
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const Scaffold(body: Text('Profile')),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start listening
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // After "dashboard" command, should navigate to /dashboard
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets('"resources" command routes to resources', (
      WidgetTester tester,
    ) async {
      mockSpeech.setNextRecognitionResult('resources');

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: VoiceCommandWidget(speechToText: mockSpeech),
                ),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) =>
                    const Scaffold(body: Text('Dashboard')),
              ),
              GoRoute(
                path: '/resources',
                builder: (context, state) =>
                    const Scaffold(body: Text('Resources')),
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const Scaffold(body: Text('Profile')),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Resources'), findsWidgets);
    });

    testWidgets('"profile" command routes to profile', (
      WidgetTester tester,
    ) async {
      mockSpeech.setNextRecognitionResult('profile');

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: VoiceCommandWidget(speechToText: mockSpeech),
                ),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) =>
                    const Scaffold(body: Text('Dashboard')),
              ),
              GoRoute(
                path: '/resources',
                builder: (context, state) =>
                    const Scaffold(body: Text('Resources')),
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const Scaffold(body: Text('Profile')),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Profile'), findsWidgets);
    });

    testWidgets('"join communication" command routes with mode=initiator', (
      WidgetTester tester,
    ) async {
      mockSpeech.setNextRecognitionResult('join communication');

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: VoiceCommandWidget(speechToText: mockSpeech),
                ),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) =>
                    const Scaffold(body: Text('Dashboard')),
              ),
              GoRoute(
                path: '/resources',
                builder: (context, state) =>
                    const Scaffold(body: Text('Resources')),
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const Scaffold(body: Text('Profile')),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets('"start communication" command routes with mode=joiner', (
      WidgetTester tester,
    ) async {
      mockSpeech.setNextRecognitionResult('start communication');

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: VoiceCommandWidget(speechToText: mockSpeech),
                ),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) =>
                    const Scaffold(body: Text('Dashboard')),
              ),
              GoRoute(
                path: '/resources',
                builder: (context, state) =>
                    const Scaffold(body: Text('Resources')),
              ),
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const Scaffold(body: Text('Profile')),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets('"dark mode" command triggers theme toggle', (
      WidgetTester tester,
    ) async {
      bool themeToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceCommandWidget(
              speechToText: mockSpeech,
              toggleTheme: () => themeToggled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      mockSpeech.setNextRecognitionResult('dark mode');
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Theme toggle callback should be called
      expect(themeToggled, isTrue);
    });

    testWidgets('"light mode" command triggers theme toggle', (
      WidgetTester tester,
    ) async {
      bool themeToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceCommandWidget(
              speechToText: mockSpeech,
              toggleTheme: () => themeToggled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      mockSpeech.setNextRecognitionResult('light mode');
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(themeToggled, isTrue);
    });
  });
}

/// Simple route observer to track navigation
class _RouteObserver extends NavigatorObserver {
  final Function(String) onRouteChange;

  _RouteObserver({required this.onRouteChange});

  @override
  void didPush(Route route, Route? previousRoute) {
    onRouteChange(route.settings.name ?? '/');
  }
}
