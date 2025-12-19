import 'package:flutter/material.dart';
import 'package:beacon_project/repositories/profile_repository.dart';
import 'package:beacon_project/models/profile_model.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository _profileRepository;

  bool _isSaved = false;
  Map<String, String> _savedData = {};
  ProfileModel? _currentProfile;

  bool get isSaved => _isSaved;
  Map<String, String> get savedData => _savedData;
  ProfileModel? get currentProfile => _currentProfile;

  ProfileViewModel(this._profileRepository);

  Future<void> loadProfile() async {
    _currentProfile = await _profileRepository.getProfile();
    if (_currentProfile != null) {
      _isSaved = true;
      _savedData = {
        "Full Name": _currentProfile!.fullName,
        "Phone Number": _currentProfile!.phone,
        "Emergency Contact Name": _currentProfile!.emergencyName,
        "Emergency Contact Number": _currentProfile!.emergencyPhone,
        "Location": _currentProfile!.location ?? "Not Provided",
      };
    } else {
      _isSaved = false;
      _savedData = {};
    }
    notifyListeners();
  }

  Future<void> saveProfile(ProfileModel profile) async {
    await _profileRepository.insertProfile(profile);
    _currentProfile = profile;
    _isSaved = true;
    _savedData = {
      "Full Name": profile.fullName,
      "Phone Number": profile.phone,
      "Emergency Contact Name": profile.emergencyName,
      "Emergency Contact Number": profile.emergencyPhone,
      "Location": profile.location ?? "Not Provided",
    };
    notifyListeners();
  }

  void resetForm() {
    _isSaved = false;
    _savedData = {};
    notifyListeners();
  }

  void setSavedState(bool saved) {
    _isSaved = saved;
    notifyListeners();
  }
}
