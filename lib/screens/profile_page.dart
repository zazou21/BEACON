// lib/screens/profile_page.dart
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Emergency Contacts')),
      body: const SafeArea(
        child: Center(child: Text('Profile setup UI goes here')),
      ),
    );
  }
}
