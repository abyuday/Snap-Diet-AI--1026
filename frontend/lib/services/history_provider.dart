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
    this.imagePath = '',
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

  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime get selectedDate => _selectedDate;

  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  List<HistoryEntry> get history => List.unmodifiable(_history);

  List<HistoryEntry> get selectedDateEntries {
    return _history.where((e) => 
      e.dateTime.year == _selectedDate.year && 
      e.dateTime.month == _selectedDate.month && 
      e.dateTime.day == _selectedDate.day
    ).toList();
  }

  int get currentStreak {
    if (_history.isEmpty) return 0;
    
    final days = _history.map((e) => DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day)).toSet().toList();
    days.sort((a, b) => b.compareTo(a)); 
    
    int streak = 0;
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime expectedDate = today;
    
    if (!days.contains(today)) {
       DateTime yesterday = today.subtract(const Duration(days: 1));
       if (!days.contains(yesterday)) {
          return 0;
       }
       expectedDate = yesterday;
    }

    for (var d in days) {
      if (d == expectedDate) {
        streak++;
        expectedDate = expectedDate.subtract(const Duration(days: 1));
      } else if (d.isBefore(expectedDate)) {
        break;
      }
    }
    return streak;
  }

  double get totalToday => _getSumForDate(DateTime.now(), (e) => e.calories);
  double get totalProteinToday => _getSumForDate(DateTime.now(), (e) => e.protein);
  double get totalCarbsToday => _getSumForDate(DateTime.now(), (e) => e.carbs);
  double get totalFatToday => _getSumForDate(DateTime.now(), (e) => e.fat);

  double get totalSelectedDate => _getSumForDate(_selectedDate, (e) => e.calories);
  double get totalProteinSelectedDate => _getSumForDate(_selectedDate, (e) => e.protein);
  double get totalCarbsSelectedDate => _getSumForDate(_selectedDate, (e) => e.carbs);
  double get totalFatSelectedDate => _getSumForDate(_selectedDate, (e) => e.fat);

  double _getSumForDate(DateTime date, double Function(HistoryEntry) selector) {
    return _history
        .where((e) => e.dateTime.year == date.year && e.dateTime.month == date.month && e.dateTime.day == date.day)
        .fold(0.0, (sum, item) => sum + selector(item));
  }

  List<double> get weeklyCalorieTrend {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return _history
          .where((e) => e.dateTime.year == date.year && e.dateTime.month == date.month && e.dateTime.day == date.day)
          .fold(0.0, (sum, item) => sum + item.calories);
    });
  }

  List<double> get monthlyCalorieTrend {
    final now = DateTime.now();
    return List.generate(30, (index) {
      final date = now.subtract(Duration(days: 29 - index));
      return _history
          .where((e) => e.dateTime.year == date.year && e.dateTime.month == date.month && e.dateTime.day == date.day)
          .fold(0.0, (sum, item) => sum + item.calories);
    });
  }

  List<double> get yearlyCalorieTrend {
    final now = DateTime.now();
    return List.generate(12, (index) {
      final month = now.month - 11 + index;
      final actualMonth = month <= 0 ? month + 12 : month;
      final actualYear = month <= 0 ? now.year - 1 : now.year;
      
      return _history
          .where((e) => e.dateTime.year == actualYear && e.dateTime.month == actualMonth)
          .fold(0.0, (sum, item) => sum + item.calories);
    });
  }

  Map<String, double> getMacrosForPeriod(int days) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    double p = 0, c = 0, f = 0;
    
    for (var entry in _history) {
      if (entry.dateTime.isAfter(cutoff)) {
        p += entry.protein;
        c += entry.carbs;
        f += entry.fat;
      }
    }
    return {'protein': p, 'carbs': c, 'fat': f};
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
