import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EduVaaniApp());
}

class EduVaaniApp extends StatelessWidget {
  const EduVaaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduVaani',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
    );
  }
}
