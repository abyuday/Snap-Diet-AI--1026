import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UserProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  String? _token;
  Map<String, dynamic>? _user;
  bool _onboardingComplete = false;

  bool get isAuthenticated => _token != null;
  bool get onboardingComplete => _onboardingComplete;

  // Core profile
  String get name   => _user?['name'] ?? 'Health Explorer';
  String get email  => _user?['email'] ?? '';
  String get rank   => _user?['rank'] ?? 'Nutrition Novice';

  // Onboarding-collected fields
  int    get age            => _user?['age']            ?? 0;
  String get gender         => _user?['gender']         ?? '';
  double get heightCm       => (_user?['height_cm']     ?? 0).toDouble();
  double get weightKg       => (_user?['weight_kg']     ?? 0).toDouble();
  double get targetWeightKg => (_user?['target_weight_kg'] ?? 0).toDouble();
  String get activityLevel  => _user?['activity_level'] ?? 'medium';
  String get goal           => _user?['goal']           ?? 'maintenance';

  // Daily goals
  int get calorieGoal => _user?['goals']?['calorieGoal'] ?? 2000;
  int get proteinGoal => _user?['goals']?['proteinGoal'] ?? 120;
  int get carbsGoal   => _user?['goals']?['carbsGoal']   ?? 250;
  int get fatGoal     => _user?['goals']?['fatGoal']     ?? 70;
  int get waterGoal   => _user?['goals']?['waterGoal']   ?? 2500;

  int currentWater = 0;

  void addWater(int amount) {
    currentWater += amount;
    notifyListeners();
  }

  void resetWater() {
    currentWater = 0;
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) return;

    final token = prefs.getString('token');
    if (token == null) return;

    _token = token;
    ApiService.authToken = token;

    final userDataStr = prefs.getString('userData');
    if (userDataStr != null && userDataStr != 'exists') {
      try {
        _user = jsonDecode(userDataStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error decoding user data: $e');
      }
    }

    _onboardingComplete = prefs.getBool('onboardingDone') ?? false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await _api.login(email, password);
    await _authenticateUser(response);
  }

  Future<void> signup(String name, String email, String password,
      int cal, int prot, int carbs, int fat) async {
    final response = await _api.signup(name, email, password, cal, prot, carbs, fat);
    await _authenticateUser(response);
  }

  Future<void> _authenticateUser(Map<String, dynamic> responseData) async {
    _token = responseData['access_token'];
    _user  = responseData['user'];
    ApiService.authToken = _token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    if (_user != null) {
      await prefs.setString('userData', jsonEncode(_user));
    } else {
      await prefs.setString('userData', 'exists');
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _onboardingComplete = false;
    ApiService.authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userData');
    await prefs.remove('onboardingDone');
    notifyListeners();
  }

  /// Called when the user completes the onboarding flow.
  Future<void> completeOnboarding({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required double targetWeightKg,
    required String activityLevel,
    required String goal,
    required int calorieGoal,
    required int proteinGoal,
    required int carbsGoal,
    required int fatGoal,
  }) async {
    _user ??= {};
    _user!['age']              = age;
    _user!['gender']           = gender;
    _user!['height_cm']        = heightCm;
    _user!['weight_kg']        = weightKg;
    _user!['target_weight_kg'] = targetWeightKg;
    _user!['activity_level']   = activityLevel;
    _user!['goal']             = goal;
    _user!['goals']            = {
      'calorieGoal': calorieGoal,
      'proteinGoal': proteinGoal,
      'carbsGoal':   carbsGoal,
      'fatGoal':     fatGoal,
      'waterGoal':   waterGoal,
    };

    _onboardingComplete = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(_user));
    await prefs.setBool('onboardingDone', true);
    notifyListeners();

    // Sync to backend in the background
    try {
      await _api.updateUser({
        'age': age, 'gender': gender,
        'height_cm': heightCm, 'weight_kg': weightKg,
        'target_weight_kg': targetWeightKg,
        'activity_level': activityLevel, 'goal': goal,
        'goals': _user!['goals'],
      });
    } catch (e) {
      debugPrint('Onboarding backend sync failed: $e');
    }
  }

  Future<void> updateGoals({int? calories, int? protein, int? carbs, int? fat, int? water}) async {
    _user ??= {};
    _user!['goals'] ??= {};

    Map<String, dynamic> goalsUpdate = {};
    if (calories != null) goalsUpdate['calorieGoal'] = calories;
    if (protein  != null) goalsUpdate['proteinGoal'] = protein;
    if (carbs    != null) goalsUpdate['carbsGoal']   = carbs;
    if (fat      != null) goalsUpdate['fatGoal']     = fat;
    if (water    != null) goalsUpdate['waterGoal']   = water;

    _user!['goals'].addAll(goalsUpdate);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(_user));
    notifyListeners();

    try {
      final updatedUser = await _api.updateUser({'goals': goalsUpdate});
      _user = updatedUser;
      await prefs.setString('userData', jsonEncode(_user));
      notifyListeners();
    } catch (e) {
      debugPrint('Backend sync failed: $e');
    }
  }

  Future<void> updateProfile(String newName, String newRank) async {
    _user ??= {};
    _user!['name'] = newName;
    _user!['rank'] = newRank;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(_user));
    notifyListeners();

    try {
      final updatedUser = await _api.updateUser({'name': newName, 'rank': newRank});
      _user = updatedUser;
      await prefs.setString('userData', jsonEncode(_user));
      notifyListeners();
    } catch (e) {
      debugPrint('Backend sync failed: $e');
    }
  }
}
