// Integration Tests for BEACON App
//
// Run all tests:
//   flutter test integration_test/
//
// Run specific test file:
//   flutter test integration_test/app_navigation_test.dart
//
// Run on a connected device:
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
//
// Run with coverage:
//   flutter test integration_test/ --coverage

import 'package:integration_test/integration_test.dart';

import 'app_navigation_test.dart' as app_navigation;
import 'profile_flow_test.dart' as profile_flow;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Run all test suites
  app_navigation.main();
  profile_flow.main();
}
