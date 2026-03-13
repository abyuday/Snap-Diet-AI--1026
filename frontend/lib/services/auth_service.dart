import 'dart:async';

class MockUser {
  final String uid = 'local_demo_user';
}

class MockCredential {
  final MockUser? user = MockUser();
}

class AuthService {
  final _controller = StreamController<MockUser?>.broadcast();
  MockUser? _user;

  AuthService() {
    // Start logged in to skip login screen for the demo
    _user = MockUser();
    Future.microtask(() => _controller.add(_user));
  }

  Stream<MockUser?> get user => _controller.stream;

  MockUser? get currentUser => _user;

  Future<MockCredential> signUp(String email, String password) async {
    _user = MockUser();
    _controller.add(_user);
    return MockCredential();
  }

  Future<MockCredential> login(String email, String password) async {
    _user = MockUser();
    _controller.add(_user);
    return MockCredential();
  }

  Future<void> logout() async {
    _user = null;
    _controller.add(null);
  }
}
