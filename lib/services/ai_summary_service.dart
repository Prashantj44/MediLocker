import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiSummaryService {
  final GenerativeModel _model;

  AiSummaryService() 
      : _model = GenerativeModel(
          model: 'gemini-3-flash-preview',
          apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        );

  Future<String> summarize(String attachmentUrl) async {
    try {
      final prompt = 'Summarize this medical report into clear, easy-to-understand bullet points. Focus on the key findings, results, and any doctor recommendations.';
      
      final ref = FirebaseStorage.instance.ref().child(attachmentUrl);
      final fileBytes = await ref.getData();
      
      if (fileBytes == null) throw Exception("Could not download file.");
      
      final dataPart = DataPart('application/pdf', fileBytes); // Assuming PDF for now, can be adapted for images

      final response = await _model.generateContent([
        Content.multi([TextPart(prompt), dataPart])
      ]);

      return response.text ?? 'Could not generate a summary.';
    } catch (e) {
      print("AI Summary Error: $e");
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('not found for api version') || errorString.contains('api key not valid')) {
        return 'Error: The provided Gemini API Key is invalid or expired. Please update your API key to generate summaries.';
      }
      return 'An error occurred while generating the summary. Please check the file and try again.';
    }
  }
}
