import 'package:flutter/material.dart';
import '../services/chatbot_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final List<Map<String, dynamic>> messages = [];

  bool isLoading = false;

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty || isLoading) {
      return;
    }

    messageController.clear();

    final history = messages
        .map((message) => {
      'role': message['role'],
      'content': message['content'],
    })
        .toList();

    setState(() {
      messages.add({
        'role': 'user',
        'content': text,
      });

      isLoading = true;
    });

    scrollToBottom();

    try {
      final reply = await ChatbotService.sendMessage(
        text,
        history,
      );

      setState(() {
        messages.add({
          'role': 'assistant',
          'content': reply,
        });

        isLoading = false;
      });

      scrollToBottom();
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chatbot connection failed: $e'),
        ),
      );
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
              child: Text(
                'Hi! How can I help you?',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            )
                : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                final bool isUser =
                    message['role'] == 'user';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth:
                      MediaQuery.of(context).size.width *
                          0.8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.blue
                          : Colors.grey.shade200,
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                    child: Text(
                      message['content'],
                      style: TextStyle(
                        fontSize: 16,
                        color: isUser
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Assistant is thinking...'),
                ],
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask something...',
                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    child: IconButton(
                      onPressed:
                      isLoading ? null : sendMessage,
                      icon: const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}