import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clears the daily news cache for testing
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  // Clear daily news cache
  await prefs.remove('daily_news_content');
  await prefs.remove('daily_news_date');
  
  print('✅ Daily news cache cleared!');
  print('Now trigger a new daily update in the app to test the formatter.');
}
