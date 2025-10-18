
import 'package:flutter/material.dart';

class UserProfilePage extends StatefulWidget {
  


  const UserProfilePage({
    super.key,
  
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyNameController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _isSaved = false;
  Map<String, String> _savedData = {};

  void _resetForm() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _phoneController.clear();
    _emergencyNameController.clear();
    _emergencyPhoneController.clear();
    _locationController.clear();
    setState(() {
      _isSaved = false;
      _savedData = {};
    });
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaved = true;
        _savedData = {
          "Full Name": _fullNameController.text,
          "Phone Number": _phoneController.text,
          "Emergency Contact Name": _emergencyNameController.text,
          "Emergency Contact Number": _emergencyPhoneController.text,
          "Location": _locationController.text.isEmpty
              ? "Not Provided"
              : _locationController.text,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Profile Saved Successfully!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('User Profile'),
        centerTitle: true,
        elevation: 3,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        actions: [
          // IconButton(
          //   icon: Icon(
          //     widget.themeMode == ThemeMode.dark
          //         ? Icons.light_mode
          //         : Icons.dark_mode,
          //   ),
          //   tooltip: 'Toggle Theme',
          //   onPressed: widget.onToggleTheme,
          // ),
        
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _isSaved ? _buildSavedInfo(colors) : _buildProfileForm(colors),
      ),
    );
  }

  // Form UI
  Widget _buildProfileForm(ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 6,
        color: colors.surfaceContainerHighest,
        shadowColor: colors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequiredTextField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  validatorMsg: 'Please enter your full name',
                  colors: colors,
                ),
                const SizedBox(height: 20),
                _buildRequiredTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  validatorMsg: 'Please enter a valid phone number',
                  keyboardType: TextInputType.phone,
                  exampleText: 'Example: +201234567890',
                  colors: colors,
                ),
                const SizedBox(height: 20),
                _buildRequiredTextField(
                  label: 'Emergency Contact Name',
                  controller: _emergencyNameController,
                  validatorMsg: 'Please enter an emergency contact name',
                  colors: colors,
                ),
                const SizedBox(height: 20),
                _buildRequiredTextField(
                  label: 'Emergency Contact Number',
                  controller: _emergencyPhoneController,
                  validatorMsg: 'Please enter a valid emergency contact number',
                  keyboardType: TextInputType.phone,
                  exampleText: 'Example: +201001112223',
                  colors: colors,
                ),
                const SizedBox(height: 20),
                _buildOptionalTextField(
                  label: 'Location (optional)',
                  controller: _locationController,
                  colors: colors,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saveForm,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 15),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _resetForm,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.secondary,
                        foregroundColor: colors.onSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 15),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Saved Info UI
  Widget _buildSavedInfo(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        color: colors.surfaceContainerHighest,
        elevation: 5,
        shadowColor: colors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: colors.tertiary, size: 80),
              const SizedBox(height: 10),
              Text(
                'Profile Information Saved',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.tertiary,
                ),
              ),
              const Divider(height: 30, thickness: 1),
              ..._savedData.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          '${entry.key}:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 17,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Information'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Required field
  Widget _buildRequiredTextField({
    required String label,
    required TextEditingController controller,
    required String validatorMsg,
    required ColorScheme colors,
    TextInputType keyboardType = TextInputType.text,
    String? exampleText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: '* ',
            style: const TextStyle(color: Colors.red, fontSize: 20),
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surfaceContainerLowest,
            hintText: 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return validatorMsg;
            if (keyboardType == TextInputType.phone &&
                !RegExp(r'^\+?\d{10,15}$').hasMatch(value)) {
              return 'Invalid phone number format';
            }
            return null;
          },
        ),
        if (exampleText != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 5),
            child: Text(
              exampleText,
              style: TextStyle(fontSize: 13, color: colors.outline),
            ),
          ),
      ],
    );
  }

  // Optional field
  Widget _buildOptionalTextField({
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surfaceContainerLowest,
            hintText: 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          ),
        ),
      ],
    );
  }

}
