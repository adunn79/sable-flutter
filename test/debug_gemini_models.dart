import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('🔍 Debugging Gemini Models...');

  // 1. Read .env file manually
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print('❌ .env file not found!');
    return;
  }

  final lines = await envFile.readAsLines();
  String? apiKey;
  for (var line in lines) {
    if (line.startsWith('GOOGLE_API_KEY=')) {
      apiKey = line.split('=')[1].trim();
      break;
    }
  }

  if (apiKey == null || apiKey.isEmpty) {
    print('❌ GOOGLE_API_KEY not found in .env');
    return;
  }
  
  print('✅ Found API Key (starts with: ${apiKey.substring(0, 5)}...)');

  // 2. Call Gemini API to list models
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
  
  try {
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final models = data['models'] as List;
      
      print('\n📋 Available Models for this API Key:');
      print('----------------------------------------');
      for (var model in models) {
        final name = model['name'].toString().replaceFirst('models/', '');
        final methods = model['supportedGenerationMethods'] ?? [];
        if (methods.contains('generateContent')) {
          print('• $name');
        }
      }
      print('----------------------------------------\n');
      
      // Suggest the best match
      final bestMatches = [
        'gemini-1.5-flash',
        'gemini-1.5-flash-latest',
        'gemini-1.5-pro',
        'gemini-pro',
        'gemini-1.0-pro'
      ];
      
      for (var match in bestMatches) {
        if (models.any((m) => m['name'].toString().contains(match))) {
          print('💡 Suggested Model ID: $match');
          break;
        }
      }
      
    } else {
      print('❌ Failed to list models: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
