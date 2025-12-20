import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/main.dart' as app;

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Flow Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Profile page shows required fields', (tester) async {
      // Setup: Not logged in, simulate clicking "Join"
      await IntegrationTestHelpers.setupPrefs(isLoggedIn: false);

      // Start app
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Navigate to setup
      await tester.tap(find.text('Join Existing Communication'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Check for required form fields
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Emergency Contact Name'), findsOneWidget);
      expect(find.text('Emergency Contact Number'), findsOneWidget);
      expect(find.text('Location (optional)'), findsOneWidget);

      // Check for Save and Reset buttons
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Profile validation shows errors for empty required fields', (tester) async {
      // Setup: Not logged in
      await IntegrationTestHelpers.setupPrefs(isLoggedIn: false);

      // Start app and navigate to setup
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);
      await tester.tap(find.text('Join Existing Communication'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Scroll down to find Save button
      await IntegrationTestHelpers.scrollToVisible(
        tester,
        find.text('Save'),
      );

      // Try to save without filling fields
      await tester.tap(find.text('Save'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Should show validation errors
      expect(find.text('Full name is required'), findsOneWidget);
    });

    testWidgets('Profile can be filled and saved', (tester) async {
      // Setup: Not logged in, dashboard mode pre-set
      SharedPreferences.setMockInitialValues({
        'is_logged_in': false,
        'dashboard_mode': 'joiner',
      });

      // Start app and navigate to setup
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);
      await tester.tap(find.text('Join Existing Communication'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Fill in the form
      final textFields = find.byType(TextFormField);
      
      // Full Name
      await tester.enterText(textFields.at(0), 'John Doe');
      await tester.pump();
      
      // Phone Number
      await tester.enterText(textFields.at(1), '+201234567890');
      await tester.pump();
      
      // Emergency Contact Name
      await tester.enterText(textFields.at(2), 'Jane Doe');
      await tester.pump();
      
      // Emergency Contact Number
      await tester.enterText(textFields.at(3), '+201098765432');
      await tester.pump();

      // Scroll to Save button
      await IntegrationTestHelpers.scrollToVisible(
        tester,
        find.text('Save'),
      );

      // Tap Save
      await tester.tap(find.text('Save'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Check for success snackbar
      expect(find.text('✔ Profile Saved Successfully!'), findsOneWidget);
    });

    testWidgets('Reset button clears all fields', (tester) async {
      // Setup: Not logged in
      await IntegrationTestHelpers.setupPrefs(isLoggedIn: false);

      // Start app and navigate to setup
      app.main();
      await IntegrationTestHelpers.pumpAndSettle(tester);
      await tester.tap(find.text('Join Existing Communication'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Fill in a field
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Test Name');
      await tester.pump();

      // Verify text is entered
      expect(find.text('Test Name'), findsOneWidget);

      // Scroll to Reset button and tap
      await IntegrationTestHelpers.scrollToVisible(
        tester,
        find.text('Reset'),
      );
      await tester.tap(find.text('Reset'));
      await IntegrationTestHelpers.pumpAndSettle(tester);

      // Text should be cleared
      expect(find.text('Test Name'), findsNothing);
    });
  });
}
