import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UserProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  String? _token;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _token != null;

  String get name => _user?['name'] ?? 'Health Explorer';
  String get email => _user?['email'] ?? '';
  String get rank => _user?['rank'] ?? 'Nutrition Novice';

  int get calorieGoal => _user?['goals']?['calorieGoal'] ?? 2000;
  int get proteinGoal => _user?['goals']?['proteinGoal'] ?? 120;
  int get carbsGoal => _user?['goals']?['carbsGoal'] ?? 250;
  int get fatGoal => _user?['goals']?['fatGoal'] ?? 70;
  int get waterGoal => _user?['goals']?['waterGoal'] ?? 2500;

  int currentWater = 0;

  void addWater(int amount) {
    currentWater += amount;
    notifyListeners();
  }
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) return;

    final token = prefs.getString('token');
    if (token == null) return;

    _token = token;
    ApiService.authToken = token;

    // TODO: Verify token via /api/auth/me if desired. We will trust it here.
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await _api.login(email, password);
    await _authenticateUser(response);
  }

  Future<void> signup(String name, String email, String password, int cal, int prot, int carbs, int fat) async {
    final response = await _api.signup(name, email, password, cal, prot, carbs, fat);
    await _authenticateUser(response);
  }

  Future<void> _authenticateUser(Map<String, dynamic> responseData) async {
    _token = responseData['access_token'];
    _user = responseData['user'];
    ApiService.authToken = _token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    await prefs.setString('userData', 'exists'); // simplistic flag
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    ApiService.authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userData');
    notifyListeners();
  }

  Future<void> updateGoals({int? calories, int? protein, int? carbs, int? fat, int? water}) async {
    // Left as mock local for now
    if (_user == null) return;
    _user!['goals'] ??= {};
    if (calories != null) _user!['goals']['calorieGoal'] = calories;
    if (protein != null) _user!['goals']['proteinGoal'] = protein;
    if (carbs != null) _user!['goals']['carbsGoal'] = carbs;
    if (fat != null) _user!['goals']['fatGoal'] = fat;
    if (water != null) _user!['goals']['waterGoal'] = water;
    notifyListeners();
  }

  Future<void> updateProfile(String newName, String newRank) async {
    if (_user == null) return;
    _user!['name'] = newName;
    _user!['rank'] = newRank;
    notifyListeners();
  }
}
