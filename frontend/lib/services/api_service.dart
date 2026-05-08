import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nutrition_result.dart';

import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiService {
  /// Override via: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  /// (Android emulator: 10.0.2.2; physical device: your machine's IP)
  static String get baseUrl {
    const String envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    if (kIsWeb) {
      // Automatically target the backend on the same IP as the frontend
      final host = Uri.base.host;
      return 'http://$host:8005';
    }
    
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8005';
    return 'http://localhost:8005';
  }

  static String? authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> signup(
      String name, String email, String password, int cal, int prot, int carbs, int fat) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'calorieGoal': cal,
        'proteinGoal': prot,
        'carbsGoal': carbs,
        'fatGoal': fat,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Signup failed');
  }

  /// Analyze a single food image via /analyze endpoint
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

  /// Analyze multiple food images (different angles) via /analyze-multi endpoint
  Future<NutritionResult> analyzeMultipleImages(List<XFile> imageFiles) async {
    if (imageFiles.isEmpty) {
      throw Exception('At least one image is required.');
    }

    // If only one image, use the single-image endpoint
    if (imageFiles.length == 1) {
      return analyzeImage(imageFiles.first);
    }

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze-multi'));
    
    for (final imageFile in imageFiles) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          await imageFile.readAsBytes(),
          filename: imageFile.name,
          contentType: MediaType.parse(imageFile.name.endsWith('.png') ? 'image/png' : 'image/jpeg'),
        ),
      );
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return NutritionResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to analyze images: ${response.body}');
    }
  }

  /// Analyze multiple food images WITH AR pose metadata via /analyze-ar endpoint.
  /// [poseData] is a list of rotation/orientation dicts captured per image.
  Future<NutritionResult> analyzeWithPoseData(
      List<XFile> imageFiles, List<Map<String, dynamic>> poseData) async {
    if (imageFiles.isEmpty) throw Exception('At least one image is required.');

    // Fallback to standard multi if no pose data
    if (poseData.isEmpty) return analyzeMultipleImages(imageFiles);

    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze-ar'));

    for (final imageFile in imageFiles) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          await imageFile.readAsBytes(),
          filename: imageFile.name,
          contentType: MediaType.parse(
              imageFile.name.endsWith('.png') ? 'image/png' : 'image/jpeg'),
        ),
      );
    }

    // Attach pose data as a JSON string field
    request.fields['pose_data'] = jsonEncode(poseData);

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return NutritionResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to analyze with AR data: ${response.body}');
    }
  }

  Future<NutritionResult> analyzeText(String query) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze-text'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query}),
    );

    if (response.statusCode == 200) {
      return NutritionResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to analyze text: ${response.body}');
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
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      // Ensure all Phase 2 keys exist with safe defaults
      decoded.putIfAbsent('recipes', () => []);
      decoded.putIfAbsent('logged_foods', () => []);
      decoded.putIfAbsent('recommendations', () => []);
      return decoded;
    } else {
      throw Exception('Failed to get chat response: ${response.body}');
    }
  }

  Future<NutritionResult> analyzeBarcode(String barcode) async {
    final response = await http.get(Uri.parse('$baseUrl/analyze-barcode?barcode=$barcode'));

    if (response.statusCode == 200) {
      return NutritionResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Barcode lookup failed: ${response.body}');
    }
  }

  Future<NutritionResult> processBarcodeImage(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/process-barcode-image'));
    
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
      throw Exception('Failed to process barcode image: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateUser(Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/auth/update'),
      headers: _headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }
}
