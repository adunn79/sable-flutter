import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
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
import 'core/ai/room_brain_initializer.dart';
import 'core/ai/model_registry_service.dart';
// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  // Wrap entire app in error zone to catch all crashes
  runZonedGuarded(() async {
    String initialRoute = '/chat'; // Define outside try block for scope visibility
    
    WidgetsFlutterBinding.ensureInitialized();
    
    // Global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🔴 Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };
    
    // 1. FIREBASE (Optional - simulator may not have Firebase configured)
    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized');
      
      // Request notification permission (iOS)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('⚠️ Firebase initialization skipped (simulator?): $e');
    }
    
    // 2. CORE SERVICES (Required - must run even if Firebase fails)
    try {
      // Load environment variables FIRST
      await AppConfig.initialize();
      debugPrint('✅ AppConfig initialized');
      
      // Initialize Hive for journal storage
      await JournalStorageService.initialize();
      await JournalStorageService.createDefaultBuckets();
      debugPrint('✅ Journal storage initialized');
      
      // Get SharedPreferences for routing and settings
      final prefs = await SharedPreferences.getInstance();
      
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
      debugPrint('❌ Core Initialization Error: $e\n$stackTrace');
    }
    
    // HEAVY SERVICES are now loaded in the Splash Screen to show UI immediately
    // See features/splash/splash_screen.dart
    
    runApp(
      ProviderScope(
        child: RestartWidget(
          child: _AppLoader(initialRoute: initialRoute), 
        ),
      ),
    );
  }, (error, stackTrace) {
    // Check if this is a known non-fatal Flutter framework bug
    final errorString = error.toString();
    final isHardwareKeyboardBug = errorString.contains('_pressedKeys.containsKey') ||
        errorString.contains('HardwareKeyboard') ||
        errorString.contains('KeyUpEvent');
    
    if (isHardwareKeyboardBug) {
      // This is a known Flutter/iOS simulator bug - log but don't crash
      debugPrint('⚠️ Suppressed HardwareKeyboard bug (simulator): $error');
      return;
    }
    
    debugPrint('🔥 FATAL ERROR: $error');
    debugPrint('Stack trace: $stackTrace');
    // Show emergency error UI
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Aeliana Crashed',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error.toString(),
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  });
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
      // Localization support for FlutterQuill and other widgets
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
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

