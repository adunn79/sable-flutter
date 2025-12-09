import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/app_shell.dart';
import 'pages/placeholder_page.dart';
import 'pages/chat/chat_page.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';
import 'package:sable/features/more/screens/more_screen.dart';
import 'package:sable/features/journal/screens/journal_timeline_screen.dart';
import 'package:sable/features/journal/widgets/journal_lock_screen.dart';
import 'package:sable/features/vital_balance/screens/vital_balance_screen.dart';
import 'package:sable/features/vital_balance/widgets/vital_balance_lock_screen.dart';
import 'package:sable/features/private_space/screens/private_space_chat_screen.dart';
import 'package:sable/features/private_space/screens/private_space_lock_screen.dart';
import 'package:sable/features/today/screens/today_screen.dart';

import 'package:sable/features/onboarding/onboarding_flow.dart';

import 'package:sable/features/safety/screens/emergency_screen.dart';

// Export a factory function to create the router with a specific initial location
GoRouter createAppRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/onboarding', 
            builder: (context, state) => OnboardingFlow(
              onComplete: () => context.go('/chat'),
            ),
          ),
          GoRoute(path: '/welcome', builder: (context, state) => const PlaceholderPage(title: 'Welcome')),
          GoRoute(path: '/chat', builder: (context, state) => const ChatPage()),
          GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),
          GoRoute(path: '/journal', builder: (context, state) => const JournalLockScreen(child: JournalTimelineScreen())),
          GoRoute(path: '/vital-balance', builder: (context, state) => const VitalBalanceLockScreen(child: VitalBalanceScreen())),
          GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
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

          GoRoute(path: '/emergency', builder: (context, state) => const EmergencyScreen()),
          GoRoute(path: '/private-space', builder: (context, state) => const PrivateSpaceLockScreen(child: PrivateSpaceChatScreen())),
        ],
      ),
    ],
  );
}

final initialRouteProvider = StateProvider<String>((ref) => '/chat');

final routerProvider = Provider<GoRouter>((ref) {
  final initialRoute = ref.watch(initialRouteProvider);
  return createAppRouter(initialRoute);
});
