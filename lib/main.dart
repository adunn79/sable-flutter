import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/aureal_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/onboarding/screens/access_denied_screen.dart';
import 'src/config/app_config.dart';
import 'src/app.dart' as legacy;
import 'features/debug/debug_dashboard.dart';
import 'features/settings/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/widgets/restart_widget.dart';
import 'features/journal/services/journal_storage_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🔴 Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };
    
    await AppConfig.initialize();
    
    // Initialize Hive for journal storage
    await JournalStorageService.initialize();
    await JournalStorageService.createDefaultBuckets();
    debugPrint('✅ Journal storage initialized');
    
    // Save ElevenLabs API key to SharedPreferences for VoiceService
    if (AppConfig.elevenLabsKey.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('eleven_labs_api_key', AppConfig.elevenLabsKey);
      await prefs.setString('voice_engine_type', 'eleven_labs');
      debugPrint('✅ ElevenLabs API key loaded from .env and saved to preferences');
    }
  } catch (e, stackTrace) {
    debugPrint('Initialization Error: $e\n$stackTrace');
  }
  runApp(
    const ProviderScope(
      child: RestartWidget(
        child: AurealApp(),
      ),
    ),
  );
}

// Inline RestartWidget removed (moved to shared file)

class AurealApp extends StatelessWidget {
  const AurealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AUREAL',
      debugShowCheckedModeBanner: false,
      theme: AurealTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AurealSplashScreen(),
      routes: {
        '/onboarding': (context) => OnboardingFlow(
              onComplete: () {
                Navigator.of(context).pushReplacementNamed('/home');
              },
            ),
        '/home': (context) => const legacy.SableApp(), // Temporary - use existing chat app
        '/access-denied': (context) => const AccessDeniedScreen(),
        '/debug': (context) => const DebugDashboard(),
        '/settings': (context) => const SettingsScreen(),
        '/splash': (context) => const AurealSplashScreen(),
      },
    );
  }
}

