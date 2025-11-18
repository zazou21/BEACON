import 'package:flutter/material.dart';



class ChatPage extends StatefulWidget {
  final String macAddress;
  const ChatPage({super.key, required this.macAddress});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  String userName = '';
  String lastSeen = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadChatHistory();
  }

  Future<void> _loadUserInfo() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      userName = 'Ali';
      lastSeen = 'Last seen: 5 min ago';
    });
  }

  Future<void> _loadChatHistory() async {
    await Future.delayed(const Duration(seconds: 1));
    List<Map<String, dynamic>> chatHistory = [
      {
        'id': 1,
        'sender': 'remote',
        'message': 'everythink ok?',
        'timestamp': '14:03',
      },
      {'id': 2, 'sender': 'local', 'message': 'yes', 'timestamp': '14:04'},
      {
        'id': 3,
        'sender': 'remote',
        'message': 'you need anything?',
        'timestamp': '14:05',
      },
    ];
    setState(() {
      messages = chatHistory;
    });
  }

  void _sendMessage(String text) {
    setState(() {
      messages.add({
        'id': messages.length + 1,
        'sender': 'local',
        'message': text.trim(),
        'timestamp': DateTime.now().toString().substring(11, 16),
      });
    });
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 10, 51, 85),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                color: const Color.fromARGB(255, 10, 51, 85),
              ),
            ),
            SizedBox(width: 10),
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

      //chat history
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                final myMessage = message['sender'] == 'local';
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
                          ? Color.fromARGB(255, 10, 51, 85)
                          : Color.fromARGB(255, 219, 214, 214),
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

          // input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: const Color.fromARGB(255, 241, 237, 237),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    print("next phase");
                  },
                  icon: Icon(
                    Icons.mic,
                    color: const Color.fromARGB(255, 210, 209, 209),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'type a message',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) _sendMessage(text);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: Color.fromARGB(255, 10, 51, 85),
                  ),
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      _sendMessage(controller.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
