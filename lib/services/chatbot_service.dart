import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  static const String apiUrl = 'http://10.21.42.2:8000/chat';

  static const String apiKey =
      '2c48d10545f4b1473ae9363de647044e02711d63ea4812fad5736169fdc8b33d';

  static Future<String> sendMessage(
      String message,
      List<Map<String, dynamic>> history,
      ) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: jsonEncode({
        'message': message,
        'history': history,
      }),
    );

    print('CHATBOT STATUS: ${response.statusCode}');
    print('CHATBOT RESPONSE: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data['reply']?.toString() ?? 'No response received.';
    }

    throw Exception(
      'Chatbot error ${response.statusCode}: ${response.body}',
    );
  }
}