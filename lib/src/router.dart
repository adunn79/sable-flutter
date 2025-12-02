import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/app_shell.dart';
import 'pages/placeholder_page.dart';
import 'pages/chat/chat_page.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(path: '/onboarding', builder: (context, state) => const PlaceholderPage(title: 'Onboarding')),
          GoRoute(path: '/welcome', builder: (context, state) => const PlaceholderPage(title: 'Welcome')),
          GoRoute(path: '/chat', builder: (context, state) => const ChatPage()),
          GoRoute(path: '/today', builder: (context, state) => const PlaceholderPage(title: 'Today')),
          GoRoute(path: '/journal', builder: (context, state) => const PlaceholderPage(title: 'Journal')),
          GoRoute(path: '/memory', builder: (context, state) => const PlaceholderPage(title: 'Memory')),
          GoRoute(path: '/share', builder: (context, state) => const PlaceholderPage(title: 'Share')),
          GoRoute(path: '/health', builder: (context, state) => const PlaceholderPage(title: 'Health')),
          GoRoute(path: '/people', builder: (context, state) => const PlaceholderPage(title: 'People')),
          GoRoute(path: '/plan', builder: (context, state) => const PlaceholderPage(title: 'Plan')),
          GoRoute(path: '/vault', builder: (context, state) => const PlaceholderPage(title: 'Vault')),
          GoRoute(path: '/moments', builder: (context, state) => const PlaceholderPage(title: 'Moments')),
          GoRoute(path: '/avatars', builder: (context, state) => const PlaceholderPage(title: 'Avatars')),
          GoRoute(path: '/timers', builder: (context, state) => const PlaceholderPage(title: 'Timers')),
          GoRoute(path: '/calendar', builder: (context, state) => const PlaceholderPage(title: 'Calendar')),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
