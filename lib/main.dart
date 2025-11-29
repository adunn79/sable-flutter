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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  runApp(const ProviderScope(child: AurealApp()));
}

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
      },
    );
  }
}

