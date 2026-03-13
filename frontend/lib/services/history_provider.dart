import 'package:flutter/material.dart';
import '../models/nutrition_result.dart';
import 'database_helper.dart';
import 'firestore_service.dart';

class HistoryEntry {
  final String foodName;
  final DateTime dateTime;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String emoji;
  final String imagePath;

  HistoryEntry({
    required this.foodName,
    required this.dateTime,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.emoji,
    required this.imagePath,
  });

  String get formattedDate => "${dateTime.day}/${dateTime.month}/${dateTime.year}";
}

class HistoryProvider extends ChangeNotifier {
  List<HistoryEntry> _history = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirestoreService _firestore = FirestoreService();
  String? _userId;

  HistoryProvider();

  void setUserId(String? uid) {
    if (_userId != uid) {
      _userId = uid;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    _history = await _dbHelper.getHistory();
    notifyListeners();
  }

  List<HistoryEntry> get history => List.unmodifiable(_history);

  double get totalToday => _getSumForToday((e) => e.calories);
  double get totalProteinToday => _getSumForToday((e) => e.protein);
  double get totalCarbsToday => _getSumForToday((e) => e.carbs);
  double get totalFatToday => _getSumForToday((e) => e.fat);

  double _getSumForToday(double Function(HistoryEntry) selector) {
    final now = DateTime.now();
    return _history
        .where((e) => e.dateTime.year == now.year && e.dateTime.month == now.month && e.dateTime.day == now.day)
        .fold(0.0, (sum, item) => sum + selector(item));
  }

  List<double> get weeklyCalorieTrend {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return _history
          .where((e) => e.dateTime.day == date.day && e.dateTime.month == date.month)
          .fold(0.0, (sum, item) => sum + item.calories);
    });
  }

  Future<void> addEntry(NutritionResult result, String imagePath) async {
    final now = DateTime.now();
    final entry = HistoryEntry(
      foodName: result.foodName,
      dateTime: now,
      calories: result.calories,
      protein: result.protein,
      carbs: result.carbs,
      fat: result.fat,
      emoji: _getEmojiForFood(result.foodName),
      imagePath: imagePath,
    );
    
    _history.insert(0, entry);
    // Save Local
    await _dbHelper.insertHistory(entry);
    
    // Save Cloud
    if (_userId != null) {
      await _firestore.addLog(_userId!, {
        'food_name': entry.foodName,
        'calories': entry.calories,
        'protein': entry.protein,
        'carbs': entry.carbs,
        'fat': entry.fat,
        'emoji': entry.emoji,
        'image_path': entry.imagePath,
        'date': entry.dateTime.toIso8601String(),
      });
    }
    
    notifyListeners();
  }

  String _getEmojiForFood(String name) {
    name = name.toLowerCase();
    if (name.contains('burger')) return '🍔';
    if (name.contains('pizza')) return '🍕';
    if (name.contains('salad')) return '🥗';
    if (name.contains('pasta')) return '🍝';
    if (name.contains('salmon') || name.contains('fish')) return '🐟';
    if (name.contains('biryani')) return '🍗';
    if (name.contains('apple')) return '🍎';
    return '🍽';
  }
}
