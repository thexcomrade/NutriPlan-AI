import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nutriplan_ai/models/ChatMessageModel.dart';
import 'package:nutriplan_ai/utils/Constants.dart';

class ChatService {
  final String baseUrl = Constants.apiBaseUrl;

  /// Sends a user message to the AI chatbot and receives a response.
  Future<ChatMessageModel?> sendMessage(String userMessage) async {
    final url = Uri.parse('$baseUrl/chat');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'message': userMessage}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ChatMessageModel.fromJson(data);
      } else {
        print('Error from server: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('ChatService Error: $e');
      return null;
    }
  }

  /// Simulates chat locally (for testing/demo purposes)
  Future<ChatMessageModel> mockChat(String message) async {
    await Future.delayed(Duration(milliseconds: 500)); // simulate latency
    return ChatMessageModel(
      message: "Hi! I'm your AI Dietician. Let's talk nutrition!",
      isUser: false,
      timestamp: DateTime.now(),
    );
  }
}
