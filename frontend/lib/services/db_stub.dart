// lib/services/db_stub.dart

/// A stub class that mimics the sqflite Database class for web compilation.
class Database {
  Future<dynamic> execute(String sql, [List<dynamic>? arguments]) async => null;
  Future<dynamic> insert(String table, Map<String, dynamic> values, {String? nullColumnHack, dynamic conflictAlgorithm}) async => 0;
  Future<dynamic> query(String table, {bool? distinct, List<String>? columns, String? where, List<dynamic>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async => [];
  Future<dynamic> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs, dynamic conflictAlgorithm}) async => 0;
  Future<dynamic> delete(String table, {String? where, List<dynamic>? whereArgs}) async => 0;
}

Future<String> getDatabasesPath() async => '';
Future<dynamic> openDatabase(String path, {int? version, Future<void> Function(Database db, int version)? onCreate, Future<void> Function(Database db, int oldVersion, int newVersion)? onUpgrade}) async => Database();
