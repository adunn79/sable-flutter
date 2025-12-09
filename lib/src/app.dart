import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sable/core/theme/aeliana_theme.dart';
import 'router.dart';

void main() {
  runApp(const ProviderScope(child: SableApp()));
}

class SableApp extends ConsumerWidget {
  final String initialRoute;
  
  const SableApp({super.key, this.initialRoute = '/chat'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Create router with the provided initial route
    final router = createAppRouter(initialRoute);

    return MaterialApp.router(
      title: 'Aeliana',
      theme: AelianaTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
    );
  }
}
