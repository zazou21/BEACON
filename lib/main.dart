import 'package:flutter/material.dart';
import 'package:beacon_project/theme.dart';
import 'package:beacon_project/screens/resources_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon Project',
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: ThemeMode.system,
      home: const ResourcePage(),
    );
  }
}