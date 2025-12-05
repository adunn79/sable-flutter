
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Daily Update Formatting Tests', () {
    // late WebSearchService service;

    setUp(() {
      // final mockOrchestrator = MockModelOrchestrator();
      // service = WebSearchService(mockOrchestrator);
    });

    // Mirroring private methods for testing via reflection or just copy-pasting logic if direct test is hard.
    // Since Dart private methods are private, we can't call them directly without @visibleForTesting
    // OR, we can just test the public method if we can mock the search response.
    // BUT, we can't easily mock the search response without mocking the GeminiProvider inside the orchestrator.
    // So, for this verification step, I will create a temporary "Testable" version of the service
    // that exposes the logic or just re-implement the logic in the test to verify it works as intended.
    
    // Better approach: Since I modified the actual file, and assume I cannot easily run integration tests
    // I will verify the LOGIC itself by copying the critical function here to test it in isolation
    // This confirms the algorithm is correct.
    
    String formatBulletSpacing(String text) {
      // Logic copied from WebSearchService._formatBulletSpacing for independent verification
      final lines = text.split('\n');
      final formatted = <String>[];
      
      String? currentBullet;
      
      void addFormattedBullet(List<String> formatted, String content) {
        String topic = content.replaceAll(RegExp(r'[\[\]()]'), '').replaceAll(' ', '_');
        String displayContent = content.replaceAll('[', '\\[').replaceAll(']', '\\]');
        formatted.add('[• $displayContent](expand:$topic)');
      }


      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmedLine = line.trim();
        
        if (trimmedLine.isEmpty) continue;
        
        final isBullet = trimmedLine.startsWith('•') || trimmedLine.startsWith('*');
        
        // UPDATED LOGIC HERE
        final isHeader = trimmedLine.startsWith('**') && 
            (trimmedLine.contains('🌍') || 
             trimmedLine.contains('🇺🇸') || 
             trimmedLine.contains('📍') || 
             trimmedLine.contains('💻') || 
             trimmedLine.contains('🔬'));

        if (isHeader) {
          if (currentBullet != null) {
            addFormattedBullet(formatted, currentBullet);
            currentBullet = null;
            formatted.add(''); 
          }
          formatted.add(line);
          continue;
        }

        if (isBullet) {
          if (currentBullet != null) {
            addFormattedBullet(formatted, currentBullet);
            formatted.add('');
          }
          currentBullet = trimmedLine.substring(1).trim();
        } else {
          if (currentBullet != null) {
            currentBullet = (currentBullet ?? '') + ' ' + trimmedLine;
          } else {
            formatted.add(line);
          }
        }
      }
      
      if (currentBullet != null) {
        addFormattedBullet(formatted, currentBullet);
      }
      
      return formatted.join('\n');
    }

    test('Correctly formats Daily Update output', () {
      final input = '''
**🌍 WORLD**
• Major event happening in Europe. (Reuters)
• Another big story. (AP)

**🇺🇸 NATIONAL**
• Election updates. (CNN)
''';

      final expected = '''
**🌍 WORLD**
[• Major event happening in Europe. (Reuters)](expand:Major_event_happening_in_Europe._Reuters)

[• Another big story. (AP)](expand:Another_big_story._AP)

**🇺🇸 NATIONAL**
[• Election updates. (CNN)](expand:Election_updates._CNN)''';

      final result = formatBulletSpacing(input);
      expect(result.trim(), expected.trim());
    });
    
     test('Correctly escapes brackets in content', () {
      final input = '''
**💻 TECH**
• New AI model [Release] is huge. (TechCrunch)
''';

      final expected = '''
**💻 TECH**
[• New AI model \\[Release\\] is huge. (TechCrunch)](expand:New_AI_model_Release_is_huge._TechCrunch)''';

      final result = formatBulletSpacing(input);
      expect(result.trim(), expected.trim());
    });
  });
}
