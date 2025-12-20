import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/main.dart' as app;

import 'helpers/test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete App Navigation Flow', (tester) async {
    // Setup initial state: Not logged in
    SharedPreferences.setMockInitialValues({
      'is_logged_in': false,
    });

    // Start app ONCE
    app.main();
    
    // Wait for app to fully load (may take time due to permissions)
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ============================================
    // TEST 1: Verify Landing Page Shows
    // ============================================
    print('[TEST] Checking landing page...');
    
    final beaconTitle = find.text('BEACON');
    final joinButton = find.text('Join Existing Communication');
    final startButton = find.text('Start New Communication');

    if (beaconTitle.evaluate().isNotEmpty) {
      print('[TEST] ✓ Found BEACON title');
    }
    
    if (joinButton.evaluate().isNotEmpty && startButton.evaluate().isNotEmpty) {
      print('[TEST] ✓ Landing page verified - both buttons present');
      
      // ============================================
      // TEST 2: Tap "Join Existing" -> Should go to Setup
      // ============================================
      print('[TEST] Tapping "Join Existing Communication"...');
      await tester.tap(joinButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check if we're on setup/profile page
      final profileHeader = find.text('Complete Your Profile');
      final fullNameField = find.text('Full Name');
      
      if (profileHeader.evaluate().isNotEmpty) {
        print('[TEST] ✓ Redirected to Profile/Setup page');
      } else if (fullNameField.evaluate().isNotEmpty) {
        print('[TEST] ✓ On Profile page (found Full Name field)');
      } else {
        print('[TEST] Current page widgets:');
        // Debug: print what's on screen
        final allText = find.byType(Text);
        for (var i = 0; i < allText.evaluate().length && i < 10; i++) {
          final widget = allText.evaluate().elementAt(i).widget as Text;
          print('  - "${widget.data}"');
        }
      }

      // ============================================
      // TEST 3: Fill Profile and Save
      // ============================================
      print('[TEST] Attempting to fill profile form...');
      
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        print('[TEST] Found ${textFields.evaluate().length} text fields');
        
        // Fill required fields
        if (textFields.evaluate().length >= 4) {
          await tester.enterText(textFields.at(0), 'Test User');
          await tester.pump();
          await tester.enterText(textFields.at(1), '+201234567890');
          await tester.pump();
          await tester.enterText(textFields.at(2), 'Emergency Contact');
          await tester.pump();
          await tester.enterText(textFields.at(3), '+201098765432');
          await tester.pump();
          print('[TEST] ✓ Filled form fields');

          // ===== DISMISS KEYBOARD =====
          // Method 1: Send "done" action to close keyboard
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          
          // Method 2: Unfocus any focused widget
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          print('[TEST] ✓ Dismissed keyboard');

          // Scroll to find Save button
          final saveButton = find.text('Save');
          await tester.ensureVisible(saveButton);
          await tester.pumpAndSettle();
          
          // Tap Save
          await tester.tap(saveButton);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          print('[TEST] ✓ Tapped Save button');

          // Check for success or dashboard
          final successSnackbar = find.text('✔ Profile Saved Successfully!');
          final dashboardTitle = find.text('Dashboard');
          
          if (successSnackbar.evaluate().isNotEmpty) {
            print('[TEST] ✓ Profile saved successfully');
          }
          
          if (dashboardTitle.evaluate().isNotEmpty) {
            print('[TEST] ✓ Navigated to Dashboard');
            
            // ============================================
            // TEST 4: Test Bottom Navigation
            // ============================================
            print('[TEST] Testing bottom navigation...');
            
            // Tap Landing icon
            final homeIcon = find.byIcon(Icons.home);
            if (homeIcon.evaluate().isNotEmpty) {
              await tester.tap(homeIcon);
              await tester.pumpAndSettle(const Duration(seconds: 2));
              
              // Check if we're on landing
              if (find.text('Join Existing Communication').evaluate().isNotEmpty) {
                print('[TEST] ✓ Bottom nav to Landing works');
              }
            }
          }
        }
      }
    } else {
      // App might have redirected somewhere else
      print('[TEST] Landing page not found. Checking current state...');
      
      final dashboard = find.text('Dashboard');
      final profile = find.text('Profile');
      
      if (dashboard.evaluate().isNotEmpty) {
        print('[TEST] App is on Dashboard (possibly already logged in)');
      } else if (profile.evaluate().isNotEmpty) {
        print('[TEST] App is on Profile page');
      }
      
      // Print visible text widgets for debugging
      final allText = find.byType(Text);
      print('[TEST] Visible text widgets:');
      for (var i = 0; i < allText.evaluate().length && i < 15; i++) {
        final widget = allText.evaluate().elementAt(i).widget as Text;
        if (widget.data != null && widget.data!.isNotEmpty) {
          print('  - "${widget.data}"');
        }
      }
    }

    print('[TEST] ============ TEST COMPLETE ============');
  });
}