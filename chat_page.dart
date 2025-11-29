import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';

class ChatPage extends StatefulWidget {
  final String macAddress;
  const ChatPage({super.key, required this.macAddress});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController controller = TextEditingController();
  final ImagePicker picker = ImagePicker();

  // ----------------- P2P -------------------
  late NearbyConnectionsInitiator p2p;

  List<Map<String, dynamic>> messages = [];
  String userName = '';
  String lastSeen = '';

  @override
  void initState() {
    super.initState();

    // Initialize the P2P service
    p2p = NearbyConnectionsInitiator();

    _loadUserInfo();
    _loadChatHistory();

    // ---------------- LISTEN FOR INCOMING TEXT ----------------
    p2p.onTextReceived = (msg) {
      setState(() {
        messages.add({
          'sender': 'remote',
          'type': 'text',
          'message': msg,
          'timestamp': _timeNow(),
        });
      });
    };

    // ---------------- LISTEN FOR INCOMING IMAGE ----------------
    p2p.onImageReceived = (Uint8List bytes) {
      setState(() {
        messages.add({
          'sender': 'remote',
          'type': 'image',
          'bytes': bytes,
          'timestamp': _timeNow(),
        });
      });
    };
  }

  // ---------------- LOAD USER INFO --------------------
  Future<void> _loadUserInfo() async {
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() {
      userName = "Ali";
      lastSeen = "Last seen: 5 min ago";
    });
  }

  // ---------------- LOAD CHAT HISTORY ----------------
  Future<void> _loadChatHistory() async {
    await Future.delayed(const Duration(milliseconds: 700));

    List<Map<String, dynamic>> chatHistory = [
      {
        'sender': 'remote',
        'type': 'text',
        'message': 'everything ok?',
        'timestamp': '14:03',
      },
      {
        'sender': 'local',
        'type': 'text',
        'message': 'yes',
        'timestamp': '14:04',
      },
      {
        'sender': 'remote',
        'type': 'text',
        'message': 'you need anything?',
        'timestamp': '14:05',
      },
    ];

    setState(() {
      messages = chatHistory;
    });
  }

  // ---------------- SEND TEXT ---------------------
  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add({
        'sender': 'local',
        'type': 'text',
        'message': text.trim(),
        'timestamp': _timeNow(),
      });
    });

    p2p.broadcastMessage(text.trim());
    controller.clear();
  }

  // ---------------- SEND IMAGE ---------------------
  Future<void> _sendImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    Uint8List bytes = await image.readAsBytes();

    setState(() {
      messages.add({
        'sender': 'local',
        'type': 'image',
        'bytes': bytes,
        'timestamp': _timeNow(),
      });
    });

    p2p.broadcastImage(bytes);
  }

  // ---------------- TIME HELPER ---------------------
  String _timeNow() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  // ---------------- UI -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 10, 51, 85),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color.fromARGB(255, 10, 51, 85)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  lastSeen,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color.fromARGB(179, 232, 227, 227),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // ---------------- CHAT HISTORY -------------------
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                final bool myMessage = message['sender'] == 'local';

                if (message['type'] == 'image') {
                  return Align(
                    alignment: myMessage
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: myMessage
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: myMessage
                                  ? const Color.fromARGB(255, 10, 51, 85)
                                  : const Color.fromARGB(255, 220, 220, 220),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                message['bytes'],
                                width: 180,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message['timestamp'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: myMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 15,
                    ),
                    decoration: BoxDecoration(
                      color: myMessage
                          ? const Color.fromARGB(255, 10, 51, 85)
                          : const Color.fromARGB(255, 219, 214, 214),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: Radius.circular(myMessage ? 15 : 0),
                        bottomRight: Radius.circular(myMessage ? 0 : 15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: myMessage
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['message'],
                          style: TextStyle(
                            color: myMessage ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          message['timestamp'],
                          style: TextStyle(
                            fontSize: 11,
                            color: myMessage ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ---------------- INPUT AREA -------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color.fromARGB(255, 241, 237, 237),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sendImage,
                  icon: const Icon(Icons.photo, color: Colors.grey),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "type a message",
                      border: InputBorder.none,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: Color.fromARGB(255, 10, 51, 85),
                  ),
                  onPressed: () => _sendMessage(controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
