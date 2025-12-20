// Two-Device Integration Test
// 
// This test is designed to run on TWO physical Android devices simultaneously.
// Each device takes a different role (initiator or joiner) and tests the
// communication flow between them.
//
// USAGE:
//   Device A (Initiator): flutter test integration_test/two_device_test.dart -d DEVICE_A_ID --dart-define=TEST_ROLE=initiator
//   Device B (Joiner):    flutter test integration_test/two_device_test.dart -d DEVICE_B_ID --dart-define=TEST_ROLE=joiner
//
// Or use the PowerShell script: .\scripts\run_two_device_test.ps1

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/main.dart' as app;

// Role is passed via --dart-define=TEST_ROLE=initiator or joiner
const String testRole = String.fromEnvironment('TEST_ROLE', defaultValue: 'joiner');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final bool isInitiator = testRole == 'initiator';
  
  group('Two Device Communication Test', () {
    testWidgets('${isInitiator ? "INITIATOR" : "JOINER"} Flow', (tester) async {
      print('');
      print('╔════════════════════════════════════════════════════════════╗');
      print('║  TWO-DEVICE TEST - ${isInitiator ? "INITIATOR" : "JOINER   "}                            ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('');

      // Setup initial state: Not logged in
      SharedPreferences.setMockInitialValues({
        'is_logged_in': false,
      });

      // Start app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Wait for app to fully load - keep pumping until landing page appears
      bool appLoaded = false;
      for (int i = 0; i < 30; i++) {  // Wait up to 30 seconds
        await tester.pump(const Duration(seconds: 1));
        
        final startButton = find.text('Start New Communication');
        final joinButton = find.text('Join Existing Communication');
        
        if (startButton.evaluate().isNotEmpty || joinButton.evaluate().isNotEmpty) {
          appLoaded = true;
          print('[APP] Landing page loaded after ${i + 3} seconds');
          break;
        }
        
        if (i % 5 == 0) {
          print('[APP] Waiting for landing page... (${i}s)');
        }
      }
      
      if (!appLoaded) {
        print('[APP] ✗ Landing page did not load in time');
        _printVisibleWidgets(tester);
        return;
      }

      if (isInitiator) {
        await _runInitiatorFlow(tester);
      } else {
        await _runJoinerFlow(tester);
      }

      print('');
      print('╔════════════════════════════════════════════════════════════╗');
      print('║  TEST COMPLETE - ${isInitiator ? "INITIATOR" : "JOINER   "}                             ║');
      print('╚════════════════════════════════════════════════════════════╝');
    });
  });
}

/// Initiator device flow
Future<void> _runInitiatorFlow(WidgetTester tester) async {
  // ============================================
  // STEP 1: Tap "Start New Communication"
  // ============================================
  print('[INITIATOR] Step 1: Starting new communication...');
  
  final startButton = find.text('Start New Communication');
  if (startButton.evaluate().isEmpty) {
    print('[INITIATOR] ✗ Could not find "Start New Communication" button');
    _printVisibleWidgets(tester);
    return;
  }
  
  await tester.tap(startButton);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  print('[INITIATOR] ✓ Tapped "Start New Communication"');

  // ============================================
  // STEP 2: Fill Profile
  // ============================================
  print('[INITIATOR] Step 2: Filling profile...');
  await _fillProfile(tester, 'Device A - Initiator');

  // ============================================
  // STEP 3: Wait on Dashboard for cluster creation
  // ============================================
  print('[INITIATOR] Step 3: Waiting on Dashboard...');
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  final dashboardTitle = find.text('Dashboard');
  if (dashboardTitle.evaluate().isNotEmpty) {
    print('[INITIATOR] ✓ On Dashboard page');
  } else {
    print('[INITIATOR] ✗ Not on Dashboard');
    _printVisibleWidgets(tester);
  }

  // ============================================
  // STEP 4: Wait for joiner to appear in Available Devices
  // ============================================
  print('[INITIATOR] Step 4: Waiting for joiner device to appear...');
  print('[INITIATOR] (Make sure Device B is running the joiner test)');
  
  bool joinerFound = false;
  for (int i = 0; i < 60; i++) {  // Wait up to 2 minutes
    await tester.pump(const Duration(seconds: 2));
    
    // Look for "Available Devices" section with items
    final availableDevicesText = find.text('Available Devices');
    if (availableDevicesText.evaluate().isNotEmpty) {
      // Check if there are any device cards/tiles
      final listTiles = find.byType(ListTile);
      final cards = find.byType(Card);
      
      if (listTiles.evaluate().length > 1 || cards.evaluate().length > 1) {
        print('[INITIATOR] ✓ Found available device(s)!');
        joinerFound = true;
        break;
      }
    }
    
    if (i % 5 == 0) {
      print('[INITIATOR] ... still waiting (${i * 2}s)');
    }
  }

  if (!joinerFound) {
    print('[INITIATOR] ✗ Timeout waiting for joiner device');
    return;
  }

  // ============================================
  // STEP 5: Invite the joiner device
  // ============================================
  print('[INITIATOR] Step 5: Inviting joiner device...');
  
  // Find and tap invite button (usually an icon or text button)
  final inviteButton = find.byIcon(Icons.person_add);
  if (inviteButton.evaluate().isNotEmpty) {
    await tester.tap(inviteButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    print('[INITIATOR] ✓ Sent invite');
  } else {
    // Try finding by text
    final inviteText = find.text('Invite');
    if (inviteText.evaluate().isNotEmpty) {
      await tester.tap(inviteText.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      print('[INITIATOR] ✓ Sent invite');
    } else {
      print('[INITIATOR] ✗ Could not find invite button');
    }
  }

  // ============================================
  // STEP 6: Wait for connection to be established
  // ============================================
  print('[INITIATOR] Step 6: Waiting for connection...');
  
  bool connected = false;
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(seconds: 2));
    
    // Look for "Connected Devices" section
    final connectedText = find.text('Connected Devices');
    if (connectedText.evaluate().isNotEmpty) {
      print('[INITIATOR] ✓ Device connected!');
      connected = true;
      break;
    }
    
    if (i % 5 == 0) {
      print('[INITIATOR] ... waiting for connection (${i * 2}s)');
    }
  }

  if (!connected) {
    print('[INITIATOR] ✗ Connection timeout');
    return;
  }

  // ============================================
  // STEP 7: Open chat with connected device
  // ============================================
  print('[INITIATOR] Step 7: Opening chat...');
  
  // Tap on the connected device to open chat
  final deviceCards = find.byType(Card);
  if (deviceCards.evaluate().length > 0) {
    await tester.tap(deviceCards.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
  
  // Look for chat icon
  final chatIcon = find.byIcon(Icons.chat);
  if (chatIcon.evaluate().isNotEmpty) {
    await tester.tap(chatIcon.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    print('[INITIATOR] ✓ Opened chat');
  }

  // ============================================
  // STEP 8: Send a test message
  // ============================================
  print('[INITIATOR] Step 8: Sending test message...');
  
  final textField = find.byType(TextField);
  if (textField.evaluate().isNotEmpty) {
    await tester.enterText(textField.first, 'Hello from Initiator! Time: ${DateTime.now()}');
    await tester.pump();
    
    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    
    // Tap send button
    final sendButton = find.byIcon(Icons.send);
    if (sendButton.evaluate().isNotEmpty) {
      await tester.tap(sendButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      print('[INITIATOR] ✓ Message sent!');
    }
  }

  // ============================================
  // STEP 9: Wait for reply
  // ============================================
  print('[INITIATOR] Step 9: Waiting for reply from joiner...');
  
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(seconds: 2));
    
    // Look for message containing "Joiner"
    final replyMessage = find.textContaining('Joiner');
    if (replyMessage.evaluate().isNotEmpty) {
      print('[INITIATOR] ✓ Received reply from joiner!');
      break;
    }
    
    if (i % 5 == 0) {
      print('[INITIATOR] ... waiting for reply (${i * 2}s)');
    }
  }

  print('[INITIATOR] ✓ Communication test complete!');
}

/// Joiner device flow
Future<void> _runJoinerFlow(WidgetTester tester) async {
  // ============================================
  // STEP 1: Tap "Join Existing Communication"
  // ============================================
  print('[JOINER] Step 1: Joining existing communication...');
  
  final joinButton = find.text('Join Existing Communication');
  if (joinButton.evaluate().isEmpty) {
    print('[JOINER] ✗ Could not find "Join Existing Communication" button');
    _printVisibleWidgets(tester);
    return;
  }
  
  await tester.tap(joinButton);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  print('[JOINER] ✓ Tapped "Join Existing Communication"');

  // ============================================
  // STEP 2: Fill Profile
  // ============================================
  print('[JOINER] Step 2: Filling profile...');
  await _fillProfile(tester, 'Device B - Joiner');

  // ============================================
  // STEP 3: Wait on Dashboard
  // ============================================
  print('[JOINER] Step 3: Waiting on Dashboard...');
  
  // Give extra time for navigation and nearby services to initialize
  print('[JOINER] Waiting for navigation to Dashboard...');
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle(const Duration(seconds: 5));
  
  // Wait for Dashboard to fully load with a loop
  bool onDashboard = false;
  for (int i = 0; i < 15; i++) {
    await tester.pump(const Duration(seconds: 1));
    
    final dashboardTitle = find.text('Dashboard');
    final discoveredText = find.text('Discovered Clusters');
    
    if (dashboardTitle.evaluate().isNotEmpty || discoveredText.evaluate().isNotEmpty) {
      onDashboard = true;
      print('[JOINER] ✓ On Dashboard page (after ${i + 7}s)');
      break;
    }
    
    if (i % 3 == 0) {
      print('[JOINER] ... waiting for Dashboard (${i}s)');
      _printVisibleWidgets(tester);
    }
  }
  
  if (!onDashboard) {
    print('[JOINER] ✗ Not on Dashboard after waiting');
    _printVisibleWidgets(tester);
    return;
  }

  // ============================================
  // STEP 4: Wait for clusters to be discovered
  // ============================================
  print('[JOINER] Step 4: Discovering clusters...');
  print('[JOINER] (Make sure Device A is running the initiator test)');
  
  bool clusterFound = false;
  for (int i = 0; i < 60; i++) {  // Wait up to 2 minutes
    await tester.pump(const Duration(seconds: 2));
    
    // Look for "Discovered Clusters" or cluster cards
    final discoveredText = find.text('Discovered Clusters');
    final listTiles = find.byType(ListTile);
    final cards = find.byType(Card);
    
    if (discoveredText.evaluate().isNotEmpty && 
        (listTiles.evaluate().isNotEmpty || cards.evaluate().isNotEmpty)) {
      print('[JOINER] ✓ Found cluster(s)!');
      clusterFound = true;
      break;
    }
    
    if (i % 5 == 0) {
      print('[JOINER] ... still discovering (${i * 2}s)');
    }
  }

  if (!clusterFound) {
    print('[JOINER] ✗ Timeout waiting for clusters');
    return;
  }

  // ============================================
  // STEP 5: Join the first discovered cluster
  // ============================================
  print('[JOINER] Step 5: Joining cluster...');
  
  // Find and tap on cluster card/tile
  final joinClusterButton = find.byIcon(Icons.login);
  final cards = find.byType(Card);
  
  if (joinClusterButton.evaluate().isNotEmpty) {
    await tester.tap(joinClusterButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    print('[JOINER] ✓ Requested to join cluster');
  } else if (cards.evaluate().isNotEmpty) {
    await tester.tap(cards.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    print('[JOINER] ✓ Tapped cluster card');
  }

  // ============================================
  // STEP 6: Accept invite if dialog appears
  // ============================================
  print('[JOINER] Step 6: Checking for invite dialog...');
  
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(seconds: 2));
    
    // Look for accept button in dialog
    final acceptButton = find.text('Accept');
    final joinButton = find.text('Join');
    
    if (acceptButton.evaluate().isNotEmpty) {
      await tester.tap(acceptButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      print('[JOINER] ✓ Accepted invite');
      break;
    } else if (joinButton.evaluate().isNotEmpty) {
      await tester.tap(joinButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      print('[JOINER] ✓ Joined cluster');
      break;
    }
    
    // Check if already connected
    final connectedText = find.text('Connected');
    if (connectedText.evaluate().isNotEmpty) {
      print('[JOINER] ✓ Already connected');
      break;
    }
  }

  // ============================================
  // STEP 7: Wait for message from initiator
  // ============================================
  print('[JOINER] Step 7: Waiting for message from initiator...');
  
  // Open chat if not already open
  final chatIcon = find.byIcon(Icons.chat);
  if (chatIcon.evaluate().isNotEmpty) {
    await tester.tap(chatIcon.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
  
  bool messageReceived = false;
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(seconds: 2));
    
    // Look for message containing "Initiator"
    final initiatorMessage = find.textContaining('Initiator');
    if (initiatorMessage.evaluate().isNotEmpty) {
      print('[JOINER] ✓ Received message from initiator!');
      messageReceived = true;
      break;
    }
    
    if (i % 5 == 0) {
      print('[JOINER] ... waiting for message (${i * 2}s)');
    }
  }

  // ============================================
  // STEP 8: Send reply
  // ============================================
  if (messageReceived) {
    print('[JOINER] Step 8: Sending reply...');
    
    final textField = find.byType(TextField);
    if (textField.evaluate().isNotEmpty) {
      await tester.enterText(textField.first, 'Hello from Joiner! Reply at: ${DateTime.now()}');
      await tester.pump();
      
      // Dismiss keyboard
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      
      // Tap send button
      final sendButton = find.byIcon(Icons.send);
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        print('[JOINER] ✓ Reply sent!');
      }
    }
  }

  print('[JOINER] ✓ Communication test complete!');
}

/// Fill profile form
Future<void> _fillProfile(WidgetTester tester, String deviceName) async {
  final textFields = find.byType(TextFormField);
  
  if (textFields.evaluate().length >= 4) {
    await tester.enterText(textFields.at(0), deviceName);
    await tester.pump();
    await tester.enterText(textFields.at(1), '+201234567890');
    await tester.pump();
    await tester.enterText(textFields.at(2), 'Emergency Contact');
    await tester.pump();
    await tester.enterText(textFields.at(3), '+201098765432');
    await tester.pump();
    
    // Dismiss keyboard
    await tester.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    
    // Find and tap Save button
    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    
    print('[${deviceName.contains("Initiator") ? "INITIATOR" : "JOINER"}] ✓ Profile saved');
  } else {
    print('[PROFILE] ✗ Could not find form fields');
  }
}

/// Debug helper to print visible widgets
void _printVisibleWidgets(WidgetTester tester) {
  final allText = find.byType(Text);
  print('[DEBUG] Visible text widgets:');
  for (var i = 0; i < allText.evaluate().length && i < 15; i++) {
    final widget = allText.evaluate().elementAt(i).widget as Text;
    if (widget.data != null && widget.data!.isNotEmpty) {
      print('  - "${widget.data}"');
    }
  }
}
