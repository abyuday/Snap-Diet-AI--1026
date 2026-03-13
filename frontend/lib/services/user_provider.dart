import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'firestore_service.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestore = FirestoreService();
  
  String? _userId;
  String _name = 'Health Explorer';
  String _rank = 'Nutrition Novice';
  
  // Daily Goals
  int _calorieGoal = 2000;
  int _proteinGoal = 120;
  int _carbsGoal = 250;
  int _fatGoal = 70;
  int _waterGoal = 2500; // ml
  
  int _currentWater = 0;

  UserProvider();

  void setUserId(String? uid) {
    if (_userId != uid) {
      _userId = uid;
      if (uid != null) {
        _loadUserData();
      }
    }
  }

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _loadUserData() async {
    if (_userId == null) return;

    // Load Local Water
    _currentWater = await _dbHelper.getWaterForToday(_todayStr);

    // Load Cloud Data (Goals & Water)
    final profile = await _firestore.getUserProfile(_userId!);
    if (profile.exists) {
      final data = profile.data() as Map<String, dynamic>;
      _name = data['name'] ?? _name;
      _rank = data['rank'] ?? _rank;
      _calorieGoal = data['calorieGoal'] ?? _calorieGoal;
      _proteinGoal = data['proteinGoal'] ?? _proteinGoal;
      _carbsGoal = data['carbsGoal'] ?? _carbsGoal;
      _fatGoal = data['fatGoal'] ?? _fatGoal;
      _waterGoal = data['waterGoal'] ?? _waterGoal;
    }

    // Load Water from Cloud for Today (as fallback or sync source)
    final cloudWater = await _firestore.getWater(_userId!, _todayStr);
    if (cloudWater.exists) {
      int water = (cloudWater.data() as Map<String, dynamic>)['amount'] ?? 0;
      if (water > _currentWater) {
        _currentWater = water;
        await _dbHelper.setWaterForToday(_todayStr, _currentWater);
      }
    }

    notifyListeners();
  }

  String get name => _name;
  String get rank => _rank;
  int get calorieGoal => _calorieGoal;
  int get proteinGoal => _proteinGoal;
  int get carbsGoal => _carbsGoal;
  int get fatGoal => _fatGoal;
  int get waterGoal => _waterGoal;
  int get currentWater => _currentWater;

  Future<void> addWater(int amount) async {
    _currentWater += amount;
    await _dbHelper.setWaterForToday(_todayStr, _currentWater);
    if (_userId != null) {
      await _firestore.saveWater(_userId!, _todayStr, _currentWater);
    }
    notifyListeners();
  }

  Future<void> updateGoals({int? calories, int? protein, int? carbs, int? fat, int? water}) async {
    if (calories != null) _calorieGoal = calories;
    if (protein != null) _proteinGoal = protein;
    if (carbs != null) _carbsGoal = carbs;
    if (fat != null) _fatGoal = fat;
    if (water != null) _waterGoal = water;

    if (_userId != null) {
      await _firestore.saveUserProfile(_userId!, {
        'calorieGoal': _calorieGoal,
        'proteinGoal': _proteinGoal,
        'carbsGoal': _carbsGoal,
        'fatGoal': _fatGoal,
        'waterGoal': _waterGoal,
      });
    }
    notifyListeners();
  }

  Future<void> updateProfile(String name, String rank) async {
    _name = name;
    _rank = rank;
    if (_userId != null) {
      await _firestore.saveUserProfile(_userId!, {'name': name, 'rank': rank});
    }
    notifyListeners();
  }
}
