import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/src/shared/weather_widget.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  
  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _saveCurrentRoute();
  }
  
  @override
  void initState() {
    super.initState();
    // Save initial route after first frame to ensure context is valid for GoRouter
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveCurrentRoute());
  }

  Future<void> _saveCurrentRoute([String? locationArg]) async {
    if (!mounted) return;
    try {
      final String location = locationArg ?? GoRouterState.of(context).uri.toString();
      final prefs = await SharedPreferences.getInstance();
      // Only save main routes we want to restore
      if (location.startsWith('/chat') || 
          location.startsWith('/today') || 
          location.startsWith('/journal') || 
          location.startsWith('/vital-balance') || 
          location.startsWith('/more') ||
          location.startsWith('/settings')) {
        await prefs.setString('last_visited_route', location);
      }
    } catch (e) {
      debugPrint('Error saving route: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're on the chat page (don't show weather there - it has its own header)
    final String location = GoRouterState.of(context).uri.toString();
    
    // Save current route persistently for resume functionality
    // We do this in build (with post frame callback) to catch every navigation change
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveCurrentRoute(location));

    final bool isChatPage = location.startsWith('/chat');
    final bool isSettingsPage = location.contains('settings');
    final bool isJournalPage = location.startsWith('/journal');
    final bool isMorePage = location.startsWith('/more');
    final bool isPrivateSpace = location.startsWith('/private-space');
    final bool isOnboarding = location.startsWith('/onboarding');
    
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          // Weather widget - only show on Today screens (hide everywhere else for cleaner UI)
          if (!isChatPage && !isSettingsPage && !isJournalPage && !isMorePage && !isPrivateSpace && !isOnboarding && !location.startsWith('/vital-balance'))
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: const SafeArea(
                child: WeatherWidget(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            height: 60, // Increased for better spacing
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 10),
            ),
            iconTheme: WidgetStateProperty.all(
              const IconThemeData(size: 18),
            ),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _calculateSelectedIndex(context),
          onDestinationSelected: (index) => _onItemTapped(index, context),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
              icon: Icon(LucideIcons.heartPulse),
              label: 'Vitals',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.menu),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/chat')) return 0;
    if (location.startsWith('/today')) return 1;
    if (location.startsWith('/journal')) return 2;
    if (location.startsWith('/vital-balance')) return 3;
    if (location.startsWith('/settings') || location.startsWith('/more')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    String route = '/chat';
    switch (index) {
      case 0:
        route = '/chat';
        break;
      case 1:
        route = '/today';
        break;
      case 2:
        route = '/journal';
        break;
      case 3:
        route = '/vital-balance';
        break;
      case 4:
        route = '/more';
        break;
    }
    
    // Explicitly save the route we are going to
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_visited_route', route);
    });
    
    context.go(route);
  }
}
