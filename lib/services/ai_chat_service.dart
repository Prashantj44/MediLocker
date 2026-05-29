import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/medical_record.dart';
import 'encryption_service.dart';

class AiChatService {
  final EncryptionService _encryptionService = EncryptionService();

  static const String _model = 'gemini-2.5-flash-lite';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Max number of records to send per request to save tokens.
  static const int _maxRecords = 5;

  Future<String> getMediResponse(String query, List<MedicalRecord> records) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return 'Error: Gemini API key not found. Please add GEMINI_API_KEY to your .env file.';
    }

    try {
      // Build the text context from records (metadata only — no file downloads)
      final contextBuffer = StringBuffer();
      
      if (records.isNotEmpty) {
        final recentRecords = records.take(_maxRecords).toList();
        contextBuffer.writeln('The user has ${records.length} total records. Below are the ${recentRecords.length} most recent. Cite by title and date.');

        for (final record in recentRecords) {
          final title = await _encryptionService.decryptData(record.title) ?? '[No Title]';
          final desc = await _encryptionService.decryptData(record.description);
          
          contextBuffer.writeln('--- Record ---');
          contextBuffer.writeln('Title: $title');
          contextBuffer.writeln('Date: ${record.date}');
          contextBuffer.writeln('Category: ${record.category}');
          if (desc != null && desc.isNotEmpty) {
            final truncatedDesc = desc.length > 500 ? '${desc.substring(0, 500)}...' : desc;
            contextBuffer.writeln('Notes: $truncatedDesc');
          }
          contextBuffer.writeln('File type: ${record.attachmentType ?? "none"}');
        }
      }

      final userMessage = records.isNotEmpty
          ? '${contextBuffer.toString()}\n\nUser query: "$query"'
          : 'User query: "$query"';

      final body = jsonEncode({
        'system_instruction': {
          'parts': [{'text': _systemPrompt}]
        },
        'contents': [
          {
            'parts': [{'text': userMessage}]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 512,
          'temperature': 0.3,
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
        return text ?? 'I could not generate a response. Please try again.';
      } else {
        final error = jsonDecode(response.body);
        final message = error['error']?['message'] ?? 'Unknown error';
        print('AI Chat Error: ${response.statusCode} - $message');
        
        if (message.toString().toLowerCase().contains('api key not valid')) {
          return 'Error: The provided Gemini API Key is invalid or expired. Please update your API key.';
        }
        if (message.toString().toLowerCase().contains('quota')) {
          return 'Error: API quota exceeded. Please try again later or check your plan at https://ai.dev/rate-limit';
        }
        return 'Error: $message';
      }
    } catch (e) {
      print("AI Chat Error: $e");
      return 'Error: $e';
    }
  }

  static const String _systemPrompt = '''
You are Medi, an AI assistant for MediLocker. Help users find info in their medical records.
Rules:
1. DO NOT give medical advice, diagnoses, or treatment suggestions. Redirect to a doctor.
2. Only use info from the provided records. If not found, say so.
3. Cite the record title and date.
4. Be concise and clear.
''';
}