import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' if (dart.library.html) '../services/db_stub.dart';
import '../services/history_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static dynamic _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<dynamic> get database async {
    if (_database != null) return _database;
    if (kIsWeb) {
      _database = "web_mock_db";
      return _database;
    }
    _database = await _initDatabase();
    return _database;
  }

  Future<dynamic> _initDatabase() async {
    if (kIsWeb) return "web_mock_db";
    String path = join(await getDatabasesPath(), 'dietitian.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(dynamic db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        foodName TEXT,
        date TEXT,
        calories REAL,
        protein REAL,
        carbs REAL,
        fat REAL,
        emoji TEXT,
        imagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE water (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        amount INTEGER
      )
    ''');
  }

  Future _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE water (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT,
          amount INTEGER
        )
      ''');
    }
  }

  // Mock data for Web
  static final List<Map<String, dynamic>> _webHistory = [];
  static final Map<String, int> _webWater = {};

  // History Methods
  Future<int> insertHistory(HistoryEntry entry) async {
    if (kIsWeb) {
      _webHistory.insert(0, {
        'foodName': entry.foodName,
        'date': entry.dateTime.toIso8601String(),
        'calories': entry.calories,
        'protein': entry.protein,
        'carbs': entry.carbs,
        'fat': entry.fat,
        'emoji': entry.emoji,
        'imagePath': entry.imagePath,
      });
      return 1;
    }
    dynamic db = await database;
    return await db.insert('history', {
      'foodName': entry.foodName,
      'date': entry.dateTime.toIso8601String(),
      'calories': entry.calories,
      'protein': entry.protein,
      'carbs': entry.carbs,
      'fat': entry.fat,
      'emoji': entry.emoji,
      'imagePath': entry.imagePath,
    });
  }

  Future<List<HistoryEntry>> getHistory() async {
    List<Map<String, dynamic>> maps;
    if (kIsWeb) {
      maps = _webHistory;
    } else {
      dynamic db = await database;
      maps = await db.query('history', orderBy: 'id DESC');
    }
    
    return List.generate(maps.length, (i) {
      DateTime dt;
      try {
        dt = DateTime.parse(maps[i]['date']);
      } catch (e) {
        dt = DateTime.now(); // Fallback for old records
      }
      return HistoryEntry(
        foodName: maps[i]['foodName'],
        dateTime: dt,
        calories: maps[i]['calories'],
        protein: maps[i]['protein'],
        carbs: maps[i]['carbs'],
        fat: maps[i]['fat'],
        emoji: maps[i]['emoji'] ?? '🍽️',
        imagePath: maps[i]['imagePath'] ?? '',
      );
    });
  }

  // Water Methods
  Future<int> setWaterForToday(String date, int amount) async {
    if (kIsWeb) {
      _webWater[date] = amount;
      return 1;
    }
    dynamic db = await database;
    // Check if entry exists for this day
    List<Map<String, dynamic>> existing = await db.query(
      'water',
      where: 'date = ?',
      whereArgs: [date],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'water',
        {'amount': amount},
        where: 'date = ?',
        whereArgs: [date],
      );
    } else {
      return await db.insert('water', {
        'date': date,
        'amount': amount,
      });
    }
  }

  Future<int> getWaterForToday(String date) async {
    if (kIsWeb) {
      return _webWater[date] ?? 0;
    }
    dynamic db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'water',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isNotEmpty) {
      return maps.first['amount'];
    }
    return 0;
  }
}
