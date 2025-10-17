// lib/screens/chat_page.dart
import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: const SafeArea(
        child: Center(child: Text('Private chat UI goes here')),
      ),
    );
  }
}