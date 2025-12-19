import 'package:flutter_test/flutter_test.dart';
import 'package:beacon_project/models/profile_model.dart';
import 'package:beacon_project/viewmodels/profile_view_model.dart';
import 'package:beacon_project/repositories/mock/mock_profile_repository.dart';

void main() {
  group('ProfileViewModel', () {
    late MockProfileRepository mockProfileRepository;
    late ProfileViewModel profileViewModel;

    setUp(() {
      mockProfileRepository = MockProfileRepository();
      profileViewModel = ProfileViewModel(mockProfileRepository);
    });

    test('loadProfile sets isSaved to true when profile exists', () async {
      final testProfile = ProfileModel(
        id: 1,
        fullName: 'John Doe',
        phone: '+201234567890',
        emergencyName: 'Jane Doe',
        emergencyPhone: '+201001112223',
        location: 'Cairo',
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      await mockProfileRepository.insertProfile(testProfile);
      await profileViewModel.loadProfile();

      expect(profileViewModel.isSaved, true);
      expect(profileViewModel.currentProfile, testProfile);
      expect(profileViewModel.savedData['Full Name'], 'John Doe');
      expect(profileViewModel.savedData['Phone Number'], '+201234567890');
    });

    test('loadProfile sets isSaved to false when profile is null', () async {
      await profileViewModel.loadProfile();

      expect(profileViewModel.isSaved, false);
      expect(profileViewModel.currentProfile, null);
      expect(profileViewModel.savedData.isEmpty, true);
    });

    test('saveProfile updates state and repository', () async {
      final newProfile = ProfileModel(
        id: 1,
        fullName: 'Alice Smith',
        phone: '+201111111111',
        emergencyName: 'Bob Smith',
        emergencyPhone: '+201222222222',
        location: 'Alexandria',
        createdAt: 1234567890,
        updatedAt: 1234567890,
      );

      await profileViewModel.saveProfile(newProfile);

      expect(profileViewModel.isSaved, true);
      expect(profileViewModel.currentProfile, newProfile);
      expect(profileViewModel.savedData['Full Name'], 'Alice Smith');
    });

    test('resetForm sets isSaved to false and clears savedData', () {
      profileViewModel.setSavedState(true);
      profileViewModel.resetForm();

      expect(profileViewModel.isSaved, false);
      expect(profileViewModel.savedData.isEmpty, true);
    });

    test('setSavedState updates isSaved correctly', () {
      profileViewModel.setSavedState(true);
      expect(profileViewModel.isSaved, true);

      profileViewModel.setSavedState(false);
      expect(profileViewModel.isSaved, false);
    });
  });
}
