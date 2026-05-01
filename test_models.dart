import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final apiKey = 'AIzaSyC8dFNI4M3hJ3ZqrmYrpi1Xrsn41OzpZZY';
  
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=' + apiKey);
  final response = await http.get(url);
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    for (var model in data['models']) {
      if (model['name'].contains('1.5')) {
        print(model['name']);
      }
    }
    print("DONE");
  } else {
    print('Error code: ' + response.statusCode.toString());
    print('Body: ' + response.body);
  }
}
