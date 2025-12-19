import 'package:beacon_project/models/profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel?> getProfile();
  Future<void> insertProfile(ProfileModel profile);
  Future<void> updateProfile(ProfileModel profile);
  Future<void> deleteProfile();
}
