import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beacon_project/viewmodels/chat_view_model.dart';
import 'package:beacon_project/repositories/chat_repository_impl.dart';
import 'package:beacon_project/repositories/chat_message_repository_impl.dart';
import 'package:beacon_project/repositories/device_repository_impl.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';

class ChatPage extends StatefulWidget {
  final String deviceUuid;
  final NearbyConnectionsBase nearby;

  const ChatPage({super.key, required this.deviceUuid, required this.nearby});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  late ChatViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final dbService = DBService();
    _viewModel = ChatViewModel(
      chatRepository: ChatRepositoryImpl(dbService),
      chatMessageRepository: ChatMessageRepositoryImpl(dbService),
      deviceRepository: DeviceRepositoryImpl(dbService),
      nearby: widget.nearby,
      deviceUuid: widget.deviceUuid,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _viewModel.sendMessage(text.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 10, 51, 85),
          title: Consumer<ChatViewModel>(
            builder: (context, viewModel, child) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: const Color.fromARGB(255, 10, 51, 85),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.device?.deviceName ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        viewModel.getLastSeenText(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color.fromARGB(179, 232, 227, 227),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Consumer<ChatViewModel>(
                builder: (context, viewModel, child) {
                  if (viewModel.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (viewModel.messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  if (viewModel.myUuid == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    reverse: true,
                    itemCount: viewModel.messages.length,
                    itemBuilder: (context, index) {
                      final message = viewModel
                          .messages[viewModel.messages.length - 1 - index];
                      final isMyMessage =
                          message.senderUuid == viewModel.myUuid;

                      return Align(
                        alignment: isMyMessage
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 15,
                          ),
                          decoration: BoxDecoration(
                            color: isMyMessage
                                ? const Color.fromARGB(255, 10, 51, 85)
                                : const Color.fromARGB(255, 219, 214, 214),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: Radius.circular(isMyMessage ? 15 : 0),
                              bottomRight: Radius.circular(
                                isMyMessage ? 0 : 15,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMyMessage
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.messageText,
                                style: TextStyle(
                                  color: isMyMessage
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                viewModel.formatTimestamp(message.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMyMessage
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: const Color.fromARGB(255, 241, 237, 237),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
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
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
