import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nutrition_result.dart';

import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  /// Override via: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  /// (Android emulator: 10.0.2.2; physical device: your machine's IP)
  static final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  Future<NutritionResult> analyzeImage(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await imageFile.readAsBytes(),
        filename: imageFile.name,
        contentType: MediaType.parse(imageFile.name.endsWith('.png') ? 'image/png' : 'image/jpeg'),
      ),
    );

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return NutritionResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to analyze image: ${response.body}');
    }
  }

  Future<List<dynamic>> searchFoods(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    final response = await http.get(Uri.parse('$baseUrl/search?q=$encoded'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search foods: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> history,
    required Map<String, dynamic> goals,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'profile': profile,
        'history': history,
        'goals': goals,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get chat response: ${response.body}');
    }
  }
}
