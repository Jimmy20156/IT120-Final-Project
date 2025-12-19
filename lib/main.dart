import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';

import 'app_theme.dart';
import 'ui/splash/splash_screen.dart';
import 'core/services/detection_storage_service.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize storage service
  await DetectionStorageService.instance.loadRecords();
  runApp(const MyApp());
}

/// Root application widget with theme support.
class MyApp extends StatefulWidget {
  const MyApp({super.key});


  /// Global key to access app state for theme toggling.
  static final GlobalKey<_MyAppState> appKey = GlobalKey<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();

  /// Toggle between light and dark theme.
  static void toggleTheme(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.toggleTheme();
  }

  /// Check if dark mode is enabled.
  static bool isDarkMode(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    return state?._isDarkMode ?? false;
  }
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void toggleTheme() {
    // Toggle dark mode
    setState(() => _isDarkMode = !_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Farm Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        cardColor: AppColors.cardBackground,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
