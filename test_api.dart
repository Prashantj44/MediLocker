import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  final apiKey = 'AIzaSyBN-sdGUUnA-ga1Aj5TKgUFW55Zgz--bSI';
  final model = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: apiKey);
  try {
    final response = await model.generateContent([Content.text('Hello')]);
    print('Response: ' + response.text!);
  } catch (e) {
    print('Error caught:');
    print(e);
  }
}
