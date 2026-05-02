import 'package:flutter/material.dart';
import 'contact_us_screen.dart';

class Message {
  final String text;
  final bool isUser;
  final bool showContactButton;
  final List<String>? options;

  Message({
    required this.text,
    required this.isUser,
    this.showContactButton = false,
    this.options,
  });
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];

  static const _teal = Color(0xFF0EA5A4);

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      'Hello! Ask anything and I will help you with common questions.',
    );
  }

  void _addBotMessage(String text,
      {bool showContactButton = false, List<String>? options}) {
    setState(() {
      _messages.add(
        Message(
          text: text,
          isUser: false,
          showContactButton: showContactButton,
          options: options,
        ),
      );
    });
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(Message(text: text, isUser: true));
    });
  }

  // ✅ When user sends message → show FAQ options
  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    _controller.clear();
    _addUserMessage(message);

    _addBotMessage(
      "Here are some common questions:",
      options: [
        "How to book parking?",
        "How to cancel booking?",
        "Payment issues",
        "How to list my parking space?",
        "Others"
      ],
    );
  }

  // ✅ Handle FAQ click
  void _handleOptionTap(String option) {
    _addUserMessage(option);

    if (option == "How to book parking?") {
      _addBotMessage("Go to Parking List → Select slot → Click Book.");
    } else if (option == "How to cancel booking?") {
      _addBotMessage("Go to My Bookings → Select booking → Cancel.");
    } else if (option == "Payment issues") {
      _addBotMessage("Please check your payment history or retry payment.");
    } else if (option == "How to list my parking space?") {
      _addBotMessage("Go to Vendor Section → Add your parking space details.");
    } else if (option == "Others") {
      _addBotMessage(
        "Please contact our support team.",
        showContactButton: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chat'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F7FF), Color(0xFFE8FFF5)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _MessageBubble(
                    message: message,
                    onContactPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactUsScreen(),
                        ),
                      );
                    },
                    onOptionTap: _handleOptionTap,
                  );
                },
              ),
            ),
            _MessageInput(
              controller: _controller,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback onContactPressed;
  final Function(String) onOptionTap;

  const _MessageBubble({
    required this.message,
    required this.onContactPressed,
    required this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF0EA5A4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),

            // ✅ FAQ buttons
            if (message.options != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.options!.map((option) {
                  return ElevatedButton(
                    onPressed: () => onOptionTap(option),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5A4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    child: Text(option,
                        style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
            ],

            // ✅ Contact button
            if (message.showContactButton) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: onContactPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5A4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Contact Us'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send, color: Color(0xFF0EA5A4)),
          ),
        ],
      ),
    );
  }
}