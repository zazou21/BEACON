// lib/screens/resources_page.dart
import 'package:flutter/material.dart';

class ResourcesPage extends StatelessWidget {
  const ResourcesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resource Sharing')),
      body: const SafeArea(
        child: Center(child: Text('Resource coordination UI goes here')),
      ),
    );
  }
}
