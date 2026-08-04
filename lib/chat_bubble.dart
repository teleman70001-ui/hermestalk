import 'package:flutter/material.dart';
import 'chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLoading;

  const ChatBubble({super.key, required this.message, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = message.isUser
        ? (isDark ? Colors.teal.shade700 : Colors.teal.shade50)
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100);
    final fg = message.isUser
        ? (isDark ? Colors.white : Colors.teal.shade900)
        : (isDark ? Colors.grey.shade200 : Colors.grey.shade900);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: message.isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: isLoading
            ? Row(children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('...', style: TextStyle(color: fg)),
              ])
            : SelectableText(
                message.text,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}
