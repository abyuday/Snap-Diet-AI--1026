class MockSnapshot {
  final Map<String, dynamic>? _data;
  final bool exists;
  MockSnapshot(this._data) : exists = _data != null;
  Map<String, dynamic>? data() => _data;
}

class MockQuerySnapshot {
  final List<dynamic> docs = [];
}

class FirestoreService {
  final Map<String, Map<String, dynamic>> _mockUsers = {};
  
  // Save/Update User Profile Data
  Future<void> saveUserProfile(String uid, Map<String, dynamic> data) async {
    _mockUsers[uid] = {...(_mockUsers[uid] ?? {}), ...data};
  }

  // Get User Profile Data
  Future<dynamic> getUserProfile(String uid) async {
    return MockSnapshot(_mockUsers[uid]);
  }

  // Add History Log
  Future<void> addLog(String uid, Map<String, dynamic> logData) async {
    // Mock ignores keeping full cloud array for pure local run in user_provider
  }

  // Listen to History Logs (Stream)
  Stream<dynamic> getLogsStream(String uid) {
    return Stream.value(MockQuerySnapshot());
  }
  
  // Save Water Intake
  Future<void> saveWater(String uid, String date, int amount) async {
    saveUserProfile(uid, {'water_$date': amount});
  }

  // Get Water for Date
  Future<dynamic> getWater(String uid, String date) async {
    final user = _mockUsers[uid] ?? {};
    if (user.containsKey('water_$date')) {
      return MockSnapshot({'amount': user['water_$date']});
    }
    return MockSnapshot(null);
  }
}
