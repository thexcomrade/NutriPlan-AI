import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  final String baseUrl;

  ChatService({required this.baseUrl});
  Future<String> sendMessage(String userMessage) async {
    final Uri url = Uri.parse('$baseUrl/chat');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': userMessage}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Expecting JSON response with a field 'reply' containing chatbot text
        if (data != null && data['reply'] != null) {
          return data['reply'] as String;
        } else {
          throw Exception('Invalid response format from chat API');
        }
      } else {
        throw Exception('Failed to fetch chatbot response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error communicating with chat backend: $e');
    }
  }
}
