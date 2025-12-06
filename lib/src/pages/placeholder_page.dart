import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () {
            // Pages accessed from More menu go back to More
            if (title == 'Certificate' || title == 'Emergency') {
              context.go('/more');
            } else {
              context.go('/chat');
            }
          },
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Coming Soon: $title',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF00FFFF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This feature is currently being ported.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
