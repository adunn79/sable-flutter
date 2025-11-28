import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.messageSquare),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.calendar),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.brain),
            label: 'Memory',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/chat')) return 0;
    if (location.startsWith('/today')) return 1;
    if (location.startsWith('/journal')) return 2;
    if (location.startsWith('/memory')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/chat');
        break;
      case 1:
        context.go('/today');
        break;
      case 2:
        context.go('/journal');
        break;
      case 3:
        context.go('/memory');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }
}
