import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Script to completely reset all app data
/// Run with: dart run scripts/reset_app_data.dart
void main() async {
  print('🔄 Resetting all app data...');
  
  try {
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('✅ SharedPreferences cleared');
    
    // Clear app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    if (await appDir.exists()) {
      await appDir.delete(recursive: true);
      print('✅ App documents directory cleared');
    }
    
    // Clear app support directory
    final supportDir = await getApplicationSupportDirectory();
    if (await supportDir.exists()) {
      await supportDir.delete(recursive: true);
      print('✅ App support directory cleared');
    }
    
    // Clear cache directory
    final cacheDir = await getTemporaryDirectory();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      print('✅ Cache directory cleared');
    }
    
    print('');
    print('✨ All app data has been reset!');
    print('🔄 Please restart the app to return to onboarding.');
    
  } catch (e) {
    print('❌ Error resetting app data: $e');
    exit(1);
  }
}
