import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/history_provider.dart';
import 'services/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Custom ErrorWidget to debug layout crashes
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: SingleChildScrollView(
        child: Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(20),
          child: Text(
            '${details.exception}\n\n${details.stack}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
      ),
    );
  };

  runApp(const DietitianAppLoader());
}

class DietitianAppLoader extends StatelessWidget {
  const DietitianAppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => UserProvider()..tryAutoLogin()),
        ChangeNotifierProxyProvider<UserProvider, HistoryProvider>(
          create: (_) => HistoryProvider(),
          update: (_, userProvider, history) {
            // Re-fetch or reset if auth state changes
            if (userProvider.isAuthenticated) {
              history?.setUserId('authenticated_user');
            } else {
              history?.setUserId(null);
            }
            return history ?? HistoryProvider();
          },
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
      title: 'SnapDiet AI',
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
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        if (userProvider.isAuthenticated) {
          return const MainShell();
        }
        return const LoginScreen();
      },
    );
  }
}
