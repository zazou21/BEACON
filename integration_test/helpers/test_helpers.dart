import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class for integration tests
class IntegrationTestHelpers {
  /// Set up SharedPreferences with mock initial values
  static Future<void> setupPrefs({
    bool isLoggedIn = false,
    String? dashboardMode,
    String? deviceUuid,
  }) async {
    final Map<String, Object> values = {
      'is_logged_in': isLoggedIn,
    };
    
    if (dashboardMode != null) {
      values['dashboard_mode'] = dashboardMode;
    }
    
    if (deviceUuid != null) {
      values['device_uuid'] = deviceUuid;
    }
    
    SharedPreferences.setMockInitialValues(values);
  }

  /// Wait for navigation to complete
  static Future<void> pumpAndSettle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }

  /// Find widget by text and tap it
  static Future<void> tapByText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    expect(finder, findsOneWidget, reason: 'Could not find widget with text: $text');
    await tester.tap(finder);
    await pumpAndSettle(tester);
  }

  /// Find widget by icon and tap it
  static Future<void> tapByIcon(WidgetTester tester, IconData icon) async {
    final finder = find.byIcon(icon);
    expect(finder, findsOneWidget, reason: 'Could not find widget with icon: $icon');
    await tester.tap(finder);
    await pumpAndSettle(tester);
  }

  /// Enter text in a TextField
  static Future<void> enterText(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    // Find by label or hint text
    final finder = find.widgetWithText(TextFormField, label);
    if (finder.evaluate().isEmpty) {
      // Try finding by ancestor
      final textField = find.byType(TextFormField);
      expect(textField, findsWidgets, reason: 'Could not find TextFormField');
    }
    await tester.enterText(finder, text);
    await tester.pump();
  }

  /// Check if we're on a specific page by looking for text
  static void expectPage(String pageIndicatorText) {
    expect(
      find.text(pageIndicatorText),
      findsOneWidget,
      reason: 'Expected to be on page with text: $pageIndicatorText',
    );
  }

  /// Check that a widget is NOT present
  static void expectNotFound(String text) {
    expect(
      find.text(text),
      findsNothing,
      reason: 'Did not expect to find text: $text',
    );
  }

  /// Custom scroll until widget is visible
  static Future<void> scrollToVisible(
    WidgetTester tester,
    Finder finder, {
    double delta = 100,
    int maxScrolls = 50,
  }) async {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) return;
    
    int scrolls = 0;
    while (finder.evaluate().isEmpty && scrolls < maxScrolls) {
      await tester.drag(scrollable.first, Offset(0, -delta));
      await tester.pumpAndSettle();
      scrolls++;
    }
  }
}
