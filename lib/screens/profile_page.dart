import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../repositories/profile_repository.dart';
import '../repositories/profile_repository_impl.dart';
import '../services/db_service.dart';
import '../models/profile_model.dart';
import '../viewmodels/profile_view_model.dart';

class UserProfilePage extends StatefulWidget {
  final bool isFirstTime; // true when coming from splash
  final ProfileRepository? profileRepository;

  const UserProfilePage({
    super.key,
    this.isFirstTime = false,
    this.profileRepository,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _isSaved = false;
  Map<String, String> _savedData = {};
  late ProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Create view model with injected or default repository
    final repository = widget.profileRepository ??
        ProfileRepositoryImpl(DBService());
    _viewModel = ProfileViewModel(repository);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await _viewModel.loadProfile();
    // Populate form fields with loaded data
    if (_viewModel.currentProfile != null) {
      final profile = _viewModel.currentProfile!;
      _fullNameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _emergencyNameController.text = profile.emergencyName;
      _emergencyPhoneController.text = profile.emergencyPhone;
      _locationController.text = profile.location ?? '';
      setState(() {
        _isSaved = _viewModel.isSaved;
        _savedData = _viewModel.savedData;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _phoneController.clear();
    _emergencyNameController.clear();
    _emergencyPhoneController.clear();
    _locationController.clear();
    _viewModel.resetForm();
    setState(() {
      _isSaved = false;
      _savedData = {};
    });
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final profile = ProfileModel(
        id: 1,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        emergencyName: _emergencyNameController.text.trim(),
        emergencyPhone: _emergencyPhoneController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _viewModel.saveProfile(profile);

      setState(() {
        _isSaved = true;
        _savedData = {
          "Full Name": profile.fullName,
          "Phone Number": profile.phone,
          "Emergency Contact Name": profile.emergencyName,
          "Emergency Contact Number": profile.emergencyPhone,
          "Location": profile.location ?? "Not Provided",
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✔ Profile Saved Successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      if (widget.isFirstTime) {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _isSaved ? _buildSavedInfo(colors) : _buildProfileUI(colors),
      ),
    );
  }

  // ---------------- UI WITH HEADER ----------------
  Widget _buildProfileUI(ColorScheme colors) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(colors),
          _buildFormCard(colors),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors,
      {String title = "Complete Your Profile", String? subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: colors.onPrimary.withOpacity(0.85),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormCard(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 6,
        shadowColor: colors.shadow,
        color: colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _requiredField(
                  label: "Full Name",
                  controller: _fullNameController,
                  validator: "Full name is required",
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _requiredField(
                  label: "Phone Number",
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: "Enter a valid phone number",
                  colors: colors,
                  example: "Example: +201234567890",
                ),
                const SizedBox(height: 16),
                _requiredField(
                  label: "Emergency Contact Name",
                  controller: _emergencyNameController,
                  validator: "Emergency contact name required",
                  colors: colors,
                ),
                const SizedBox(height: 16),
                _requiredField(
                  label: "Emergency Contact Number",
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  validator: "Enter a valid emergency number",
                  colors: colors,
                  example: "Example: +201001112223",
                ),
                const SizedBox(height: 16),
                _optionalField(
                  label: "Location (optional)",
                  controller: _locationController,
                  colors: colors,
                ),
                const SizedBox(height: 28),
                _buildButtons(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _saveForm,
          icon: const Icon(Icons.save, size: 20),
          label: const Text("Save"),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _resetForm,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text("Reset"),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.secondary,
            foregroundColor: colors.onSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _requiredField({
    required String label,
    required TextEditingController controller,
    required String validator,
    required ColorScheme colors,
    TextInputType keyboardType = TextInputType.text,
    String? example,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: "* ",
            style: const TextStyle(color: Colors.red, fontSize: 20),
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: _inputDecoration(colors),
          style: const TextStyle(fontSize: 16),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return validator;
            if (keyboardType == TextInputType.phone &&
                !RegExp(r'^\+?\d{10,15}$').hasMatch(value)) {
              return 'Invalid phone number format';
            }
            if (label.contains("Name") && RegExp(r'[0-9]').hasMatch(value)) {
              return 'Names cannot contain numbers';
            }
            return null;
          },
        ),
        if (example != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(example,
                style: TextStyle(color: colors.outline, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _optionalField({
    required String label,
    required TextEditingController controller,
    required ColorScheme colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: _inputDecoration(colors),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(ColorScheme colors) {
    return InputDecoration(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      hintText: "Enter value...",
      hintStyle: TextStyle(fontSize: 16, color: colors.outline),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    );
  }

  Widget _buildSavedInfo(ColorScheme colors) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(colors, title: "Profile Completed"),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 5,
              color: colors.surfaceContainerHighest,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: colors.tertiary, size: 60),
                    const SizedBox(height: 10),
                    Text(
                      "Profile Saved",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.tertiary,
                      ),
                    ),
                    const Divider(height: 30, thickness: 1),
                    ..._savedData.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text("${e.key}:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: colors.onSurface)),
                            ),
                            Expanded(
                              flex: 6,
                              child: Text(e.value,
                                  style: TextStyle(
                                      fontSize: 16, color: colors.onSurface)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 25),
                    
                    // ************** EDIT BUTTON (FIXED) **************
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSaved = false; // Show form with existing values
                        });
                      },
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text("Edit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
