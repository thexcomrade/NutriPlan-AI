import 'package:flutter/material.dart';
import '../components/AppTheme.dart';

/// Widget to display a chat bubble for a single message.
/// Differentiates between user and AI messages with different styling.
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUserMessage;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isUserMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Bubble alignment and color depends on sender
    final alignment = isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isUserMessage ? AppTheme.primaryColor : Colors.grey.shade300;
    final textColor = isUserMessage ? Colors.white : Colors.black87;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: isUserMessage ? const Radius.circular(18) : const Radius.circular(4),
      bottomRight: isUserMessage ? const Radius.circular(4) : const Radius.circular(18),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
