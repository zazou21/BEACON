import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beacon_project/screens/profile_page.dart';
import 'package:beacon_project/models/profile_model.dart';
import 'package:beacon_project/repositories/mock/mock_profile_repository.dart';

void main() {
  group('UserProfilePage Widget Tests', () {
    late MockProfileRepository mockRepository;

    setUp(() {
      mockRepository = MockProfileRepository();
    });

    Widget createTestApp() {
      return MaterialApp(
        home: UserProfilePage(
          profileRepository: mockRepository,
        ),
      );
    }

    testWidgets('Profile page renders without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Page should render successfully
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
    });

    testWidgets('Profile page displays form when no profile is saved',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify form is displayed with all text fields
      expect(find.byType(TextFormField), findsWidgets);
      // Should have 5 text form fields: Full Name, Phone, Emergency Name, Emergency Phone, Location
      expect(find.byType(TextFormField), findsNWidgets(5));
      // Verify header text
      expect(find.text('Complete Your Profile'), findsOneWidget);
    });

    testWidgets('Profile page displays saved profile when it exists',
        (WidgetTester tester) async {
      final testProfile = ProfileModel(
        id: 1,
        fullName: 'John Doe',
        phone: '+201234567890',
        emergencyName: 'Jane Doe',
        emergencyPhone: '+201001112223',
        location: 'Cairo',
      );

      await mockRepository.insertProfile(testProfile);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify saved profile display
      expect(find.text('Profile Completed'), findsOneWidget);
      expect(find.text('Profile Saved'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('+201234567890'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('+201001112223'), findsOneWidget);
    });

    testWidgets('User can enter text into form fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);

      // Enter text in first field (Full Name)
      await tester.enterText(textFields.first, 'Test Name');
      await tester.pumpAndSettle();

      expect(find.text('Test Name'), findsOneWidget);
    });

    testWidgets('Save icon button is visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final saveIcon = find.byIcon(Icons.save);
      expect(saveIcon, findsOneWidget);
    });

    testWidgets('Reset icon button is visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final resetIcon = find.byIcon(Icons.refresh);
      expect(resetIcon, findsOneWidget);
    });

    testWidgets('Edit button appears when profile is saved',
        (WidgetTester tester) async {
      final testProfile = ProfileModel(
        id: 1,
        fullName: 'John Doe',
        phone: '+201234567890',
        emergencyName: 'Jane Doe',
        emergencyPhone: '+201001112223',
      );

      await mockRepository.insertProfile(testProfile);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Edit button should be visible
      final editButton = find.byIcon(Icons.edit);
      expect(editButton, findsOneWidget);
    });

    testWidgets('Profile page has correct structure',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('Form fields are TextFormField widgets',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final formFields = find.byType(TextFormField);
      expect(formFields, findsWidgets);
    });

    testWidgets('Profile contains check circle icon when saved',
        (WidgetTester tester) async {
      final testProfile = ProfileModel(
        id: 1,
        fullName: 'John Doe',
        phone: '+201234567890',
        emergencyName: 'Jane Doe',
        emergencyPhone: '+201001112223',
      );

      await mockRepository.insertProfile(testProfile);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Check circle should be visible
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

 



    testWidgets('Form validation requires all fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Try to save without filling fields
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Should stay on form (not navigate)
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('Saved data is retrieved from repository on load',
        (WidgetTester tester) async {
      final testProfile = ProfileModel(
        id: 1,
        fullName: 'Pre-existing User',
        phone: '+209999999999',
        emergencyName: 'Emergency Contact',
        emergencyPhone: '+208888888888',
        location: 'Test Location',
      );

      await mockRepository.insertProfile(testProfile);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify that pre-existing profile is loaded and displayed
      expect(find.text('Profile Completed'), findsOneWidget);
      expect(find.text('Pre-existing User'), findsOneWidget);
      expect(find.text('+209999999999'), findsOneWidget);
      expect(find.text('Test Location'), findsOneWidget);
    });
  });
}
