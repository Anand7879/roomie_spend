import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with fallback error logging to prevent startup crashes
  // if native config files (google-services.json) are missing.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("------------------------------------------------------------------");
    debugPrint("Firebase Core Initialization Warning: ${e.toString()}");
    debugPrint("Please configure your Firebase credentials to enable Phone Auth and Firestore.");
    debugPrint("------------------------------------------------------------------");
  }

  // Wrap the root app in a ProviderScope to enable Riverpod state tracking
  runApp(
    const ProviderScope(
      child: RoomieSpendApp(),
    ),
  );
}

/// The root widget of the RoomieSpend mobile application.
/// Configures the premium fintech light theme and launches the animated splash screen.
class RoomieSpendApp extends StatelessWidget {
  const RoomieSpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoomieSpend',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
