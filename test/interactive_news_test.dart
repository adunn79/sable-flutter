import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/features/web/services/web_search_service.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/src/config/app_config.dart';

/// Test to verify interactive news formatting
void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  test('Interactive News Formatting Test', () async {
    print('\n🧪 Testing Interactive News Formatting...\n');
    
    final container = ProviderContainer();
    final webService = container.read(webSearchServiceProvider);
    
    // Trigger a daily briefing
    final categories = ['Tech'];
    print('📡 Fetching daily briefing...');
    
    final result = await webService.getDailyBriefing(categories);
    
    print('\n📰 FORMATTED NEWS OUTPUT:');
    print('=' * 80);
    print(result);
    print('=' * 80);
    
    // Check for interactive links
    final lines = result.split('\n');
    int bulletCount = 0;
    int interactiveCount = 0;
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Check for bullet points (exclude headers which start with **)
      // Formatted bullets start with [• or [*
      // Raw bullets start with * or •
      bool isBullet = false;
      
      if (trimmed.startsWith('[•') || trimmed.startsWith('[*')) {
        isBullet = true;
      } else if ((trimmed.startsWith('*') || trimmed.startsWith('•')) && !trimmed.startsWith('**')) {
        isBullet = true;
      }
      
      if (isBullet) {
        bulletCount++;
        // Check for link format: * [Content](expand:Topic) or [• Content](expand:Topic)
        if (trimmed.contains('](expand:')) {
          interactiveCount++;
          
          // Extract topic
          final match = RegExp(r'\(expand:(.*?)\)').firstMatch(trimmed);
          if (match != null) {
            print('   🔗 Found interactive link for topic: "${match.group(1)}"');
          }
        }
      }
    }
    
    print('\n📈 INTERACTIVITY ANALYSIS:');
    print('   Total bullets: $bulletCount');
    print('   Interactive bullets: $interactiveCount');
    print('   Interactivity ratio: ${(interactiveCount / bulletCount * 100).toStringAsFixed(1)}%');
    
    // Expect at least 80% of bullets to be interactive
    if (bulletCount > 0) {
      expect(interactiveCount / bulletCount, greaterThan(0.8), 
        reason: 'Most bullets should be interactive links');
    }
    
    print('\n✅ Test PASSED! News is interactive.\n');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
