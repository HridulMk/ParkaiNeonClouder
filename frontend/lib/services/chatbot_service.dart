import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class ChatbotService {
  static Future<Map<String, dynamic>> sendMessage(String message) async {
    final url = Uri.parse('${ApiService.baseUrl}/chatbot/');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json', // ✅ direct header
      },
      body: jsonEncode({
        'message': message,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message: ${response.statusCode}');
    }
  }
}