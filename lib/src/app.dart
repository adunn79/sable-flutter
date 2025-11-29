import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sable/core/theme/aureal_theme.dart';
import 'router.dart';

void main() {
  runApp(const ProviderScope(child: SableApp()));
}

class SableApp extends ConsumerWidget {
  const SableApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Aureal',
      theme: AurealTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
