import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sable/src/config/app_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Quick diagnostic script to list available Gemini models
void main() async {
  await AppConfig.initialize();
  
  final apiKey = dotenv.env['GOOGLE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ GOOGLE_API_KEY not found in environment');
    return;
  }
  
  print('🔍 Checking available Gemini models...\n');
  
  // Try a few common model names
  final modelsToTry = [
    'gemini-pro',
    'gemini-1.5-pro',
    'gemini-1.5-flash',
    'gemini-1.5-pro-latest',
    'gemini-1.5-flash-latest',
  ];
  
  for (final modelId in modelsToTry) {
    try {
      print('Testing: $modelId');
      final model = GenerativeModel(
        model: modelId,
        apiKey: apiKey,
      );
      
      final response = await model.generateContent([Content.text('Say "OK"')]);
      
      if (response.text != null) {
        print('  ✅ WORKS! Response: ${response.text}\n');
      } else {
        print('  ⚠️  No text in response\n');
      }
    } catch (e) {
      print('  ❌ Error: $e\n');
    }
  }
}
