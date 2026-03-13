// Firebase imports removed for local mock demo
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/history_provider.dart';
import 'services/user_provider.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase initialization bypassed for mock demo
  
  runApp(const DietitianAppLoader());
}

class DietitianAppLoader extends StatelessWidget {
  const DietitianAppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => ApiService()),
        StreamProvider<MockUser?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
        ChangeNotifierProxyProvider<MockUser?, HistoryProvider>(
          create: (_) => HistoryProvider(),
          update: (_, user, history) => history!..setUserId(user?.uid),
        ),
        ChangeNotifierProxyProvider<MockUser?, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, user, profile) => profile!..setUserId(user?.uid),
        ),
      ],
      child: const DietitianApp(),
    );
  }
}

class DietitianApp extends StatelessWidget {
  const DietitianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Dietitian',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<MockUser?>(context);
    
    // If authenticated, show app, otherwise show login
    if (user != null) {
      return const MainShell();
    }
    return const LoginScreen();
  }
}
