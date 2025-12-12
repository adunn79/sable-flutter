import 'package:flutter/material.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

/// Safe utility for showing SnackBars without crashing on missing Scaffold
class SafeSnackBar {
  /// Safely show a SnackBar, catching errors if no Scaffold is in the tree
  /// Returns true if successful, false if no Scaffold was found
  static bool show(BuildContext context, SnackBar snackBar) {
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(snackBar);
        return true;
      }
      debugPrint('⚠️ SafeSnackBar: No ScaffoldMessenger found in context');
      return false;
    } catch (e) {
      debugPrint('⚠️ SafeSnackBar: Failed to show snackbar: $e');
      return false;
    }
  }

  /// Helper to show a simple text snackbar
  static bool showText(BuildContext context, String message, {Color? color}) {
    return show(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? AelianaColors.carbon,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Helper to show a success snackbar
  static bool showSuccess(BuildContext context, String message) {
    return show(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: AelianaColors.plasmaCyan,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Helper to show an error snackbar
  static bool showError(BuildContext context, String message) {
    return show(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
