import 'package:beacon_project/repositories/profile_repository.dart';
import 'package:beacon_project/models/profile_model.dart';

class MockProfileRepository implements ProfileRepository {
  ProfileModel? _profile;

  @override
  Future<ProfileModel?> getProfile() async {
    return _profile;
  }

  @override
  Future<void> insertProfile(ProfileModel profile) async {
    _profile = profile;
  }

  @override
  Future<void> updateProfile(ProfileModel profile) async {
    _profile = profile;
  }

  @override
  Future<void> deleteProfile() async {
    _profile = null;
  }
}
