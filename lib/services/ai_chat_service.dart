import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/medical_record.dart';
import 'encryption_service.dart';

class AiChatService {
  final GenerativeModel _model;
  final EncryptionService _encryptionService = EncryptionService();

  AiChatService()
      : _model = GenerativeModel(
          model: 'gemini-3-flash-preview',
          apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
          systemInstruction: Content.text(_systemPrompt),
        );

  Future<String> getMediResponse(String query, List<MedicalRecord> records) async {
    if (_apiKey == 'YOUR_API_KEY') {
      return 'Error: Please add your Gemini API key to the AiChatService.';
    }

    try {
      final contentParts = <Part>[];

      // Add the user's query as the first part
      contentParts.add(TextPart('User query: "$query"'));

      if (records.isNotEmpty) {
        contentParts.add(TextPart('Use the following medical records to answer the user query. When you provide an answer, you MUST cite the source record by its title and date.'));

        // Download file content and add it to the request
        for (final record in records) {
          final title = await _encryptionService.decryptData(record.title) ?? '[No Title]';
          final recordIntro = 'Record Title: "$title"\nDate: ${record.date}';

          Uint8List? fileBytes;
          if (record.attachmentUrl != null && record.attachmentUrl!.isNotEmpty) {
            try {
              final ref = FirebaseStorage.instance.ref().child(record.attachmentUrl!);
              fileBytes = await ref.getData();
            } catch (e) {
              print('Failed to download file: ${record.attachmentUrl}, Error: $e');
            }
          }

          if (fileBytes != null) {
            contentParts.add(TextPart(recordIntro));
            contentParts.add(DataPart(_getMimeType(record.attachmentType), fileBytes));
          } else {
             // If there is no file, just send the metadata
            contentParts.add(TextPart('$recordIntro\n[No file attached, use metadata only]'));
          }
        }
      }

      final response = await _model.generateContent([Content.multi(contentParts)]);
      return response.text ?? 'I could not generate a response. Please try again.';
    } catch (e) {
      print("AI Chat Error: $e");
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('not found for api version') || errorString.contains('api key not valid')) {
        return 'Error: The provided Gemini API Key is invalid or expired. Please update your API key in the code or backend to use Medi AI.';
      }
      return 'An error occurred while getting a response. Please try again.';
    }
  }

  String _getMimeType(String? attachmentType) {
    switch (attachmentType) {
      case 'pdf':
        return 'application/pdf';
      case 'image':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  static const String _systemPrompt = '''
  You are an AI assistant named Medi. Your sole purpose is to help users find and understand information contained exclusively within their personal medical records stored in the MediLocker application.

  ### Rules and Constraints:
  1.  **DO NOT PROVIDE MEDICAL ADVICE:** You are strictly forbidden from interpreting results, giving diagnoses, or offering treatment suggestions. You are a data-retrieval tool, not a healthcare professional. If asked for advice, you must decline politely and redirect the user to a healthcare professional. Example: "I cannot provide medical advice or interpret these results for you. For any questions about your health, it is always best to consult with your doctor or a qualified healthcare provider."
  2.  **STICK TO THE PROVIDED RECORDS:** Base all your answers exclusively on the information contained within the user's documents. If the information is not in the records, you must state that clearly. Example: "I've searched your records, but I couldn't find any information about your last tetanus shot."
  3.  **CITE SOURCES:** When you provide an answer, you must cite the source record. Mention the record's title and date.
  4.  **HANDLE AMBIGUITY:** If a user's question is vague, ask for clarification before providing an answer.
  5.  **TONE:** Be professional, empathetic, clear, and concise. Your language should be simple and easy to understand.
  ''';
}