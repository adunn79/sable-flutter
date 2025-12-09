import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/aeliana_theme.dart';
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
import 'features/journal/screens/journal_timeline_screen.dart';
import 'core/memory/unified_memory_service.dart';

void main() async {
  String initialRoute = '/chat'; // Define outside try block for scope visibility
  
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
    
    // Initialize unified memory service (chat, memories, health)
    await UnifiedMemoryService().initialize();
    debugPrint('✅ Unified memory service initialized');
    
    // Check for startup route
    final prefs = await SharedPreferences.getInstance();
    
    // Keep existing ElevenLabs logic
    if (AppConfig.elevenLabsKey.isNotEmpty) {
      await prefs.setString('eleven_labs_api_key', AppConfig.elevenLabsKey);
      await prefs.setString('voice_engine_type', 'eleven_labs');
      debugPrint('✅ ElevenLabs API key loaded from .env and saved to preferences');
    }
    
    // New: Check for last tab resume
    final shouldResume = prefs.getBool('start_on_last_tab') ?? false;
    final lastRoute = prefs.getString('last_visited_route');
    
    debugPrint('🔍 Resume Check: start_on_last_tab=$shouldResume, last_visited_route=$lastRoute');
    
    if (shouldResume && lastRoute != null && lastRoute.isNotEmpty) {
      initialRoute = lastRoute;
      debugPrint('🏁 Resuming session at: $initialRoute');
    } else {
      debugPrint('⏭️ Not resuming: shouldResume=$shouldResume, lastRoute=$lastRoute');
    }
  } catch (e, stackTrace) {
    debugPrint('Initialization Error: $e\n$stackTrace');
  }
  
  runApp(
    ProviderScope(
      child: RestartWidget(
        child: _AppLoader(initialRoute: initialRoute), 
      ),
    ),
  );
}

class _AppLoader extends StatelessWidget {
  final String initialRoute;
  const _AppLoader({required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return AelianaApp(initialRoute: initialRoute);
  }
}

class AelianaApp extends StatelessWidget {
  final String initialRoute;
  
  const AelianaApp({super.key, this.initialRoute = '/chat'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AELIANA',
      debugShowCheckedModeBanner: false,
      theme: AelianaTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AelianaSplashScreen(),
      routes: {
        '/onboarding': (context) => OnboardingFlow(
              onComplete: () {
                Navigator.of(context).pushReplacementNamed('/home');
              },
            ),
        '/home': (context) => legacy.SableApp(initialRoute: initialRoute),
        '/access-denied': (context) => const AccessDeniedScreen(),
        '/debug': (context) => const DebugDashboard(),
        '/settings': (context) => const SettingsScreen(),
        '/splash': (context) => const AelianaSplashScreen(),
        '/journal': (context) => const JournalTimelineScreen(),
      },
    );
  }
}

