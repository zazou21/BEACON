import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/main.dart' as app;

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Navigation Flow Tests', () {
    setUp(() async {
      // Reset preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Fresh app start shows landing page', (tester) async {
      // Setup: Not logged in
      await IntegrationTestHelpers.setupPrefs(isLoggedIn: false);

      // Start app
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Verify landing page
      expect(find.text('BEACON'), findsWidgets);
      expect(find.text('Join Existing Communication'), findsOneWidget);
      expect(find.text('Start New Communication'), findsOneWidget);
    });

    testWidgets('Tapping "Join Existing" redirects to setup when not logged in', (tester) async {
      // Setup: Not logged in
      await IntegrationTestHelpers.setupPrefs(isLoggedIn: false);

      // Start app
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Tap "Join Existing Communication"
      await tester.tap(find.text('Join Existing Communication'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Should be on profile/setup page
      expect(find.text('Complete Your Profile'), findsOneWidget);
    });

    testWidgets('Tapping "Start New" redirects to setup when not logged in', (tester) async {
      // Setup: Not logged in
      await IntegrationTestHelpers.setupPrefs(isLoggedIn: false);

      // Start app
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Tap "Start New Communication"
      await tester.tap(find.text('Start New Communication'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Should be on profile/setup page
      expect(find.text('Complete Your Profile'), findsOneWidget);
    });

    testWidgets('Logged in user is redirected to dashboard on app start', (tester) async {
      // Setup: Logged in with joiner mode
      await IntegrationTestHelpers.setupPrefs(
        isLoggedIn: true,
        dashboardMode: 'joiner',
        deviceUuid: 'test-uuid-123',
      );

      // Start app
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Should be on dashboard, NOT landing
      expect(find.text('Dashboard'), findsOneWidget);
      // Landing page specific text should not be visible
      expect(find.text('Join Existing Communication'), findsNothing);
    });

    testWidgets('Bottom nav Landing button works for logged in user', (tester) async {
      // Setup: Logged in
      await IntegrationTestHelpers.setupPrefs(
        isLoggedIn: true,
        dashboardMode: 'joiner',
        deviceUuid: 'test-uuid-123',
      );

      // Start app
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Should be on dashboard
      expect(find.text('Dashboard'), findsOneWidget);

      // Tap Landing in bottom nav
      await tester.tap(find.byIcon(Icons.home));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Should now be on landing page
      expect(find.text('Join Existing Communication'), findsOneWidget);
    });
  });
}
