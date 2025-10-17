// lib/screens/dashboard_page.dart
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  final String? mode;
  const DashboardPage({Key? key, this.mode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Dashboard')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Dashboard mode: ${mode ?? 'unknown'}'),
                const SizedBox(height: 16),
                const Text('Nearby devices will be listed here.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}