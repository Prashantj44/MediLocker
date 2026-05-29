import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiSummaryService {
  static const String _model = 'gemini-2.5-flash-lite';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  Future<String> summarize(String attachmentUrl) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return 'Error: Gemini API key not found. Please add GEMINI_API_KEY to your .env file.';
    }

    try {
      final ref = FirebaseStorage.instance.ref().child(attachmentUrl);
      final fileBytes = await ref.getData();
      
      if (fileBytes == null) throw Exception("Could not download file.");
      
      final mimeType = attachmentUrl.toLowerCase().endsWith('.pdf') 
          ? 'application/pdf' 
          : 'image/jpeg';
      
      final base64Data = base64Encode(fileBytes);

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Summarize this medical report in 5-7 concise bullet points. Focus on key findings, results, and recommendations.'},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Data,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 400,
          'temperature': 0.2,
        }
      });

      final url = Uri.parse('$_baseUrl/models/$_model:generateContent');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? 'Could not generate a summary.';
      } else {
        final error = jsonDecode(response.body);
        final message = error['error']?['message'] ?? 'Unknown error';
        print('AI Summary Error: ${response.statusCode} - $message');
        return 'Error: $message';
      }
    } catch (e) {
      print("AI Summary Error: $e");
      return 'Error: $e';
    }
  }
}
