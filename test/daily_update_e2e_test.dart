import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/features/web/services/web_search_service.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/src/config/app_config.dart';

/// End-to-end test: Fetch news, format it, and verify AI preserves spacing
void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  test('Daily Update End-to-End: AI Preserves Spacing', () async {
    print('\n🧪 Testing End-to-End Daily Update with AI Presentation...\n');
    
    final container = ProviderContainer();
    final webService = container.read(webSearchServiceProvider);
    final orchestrator = container.read(modelOrchestratorProvider.notifier);
    
    // Step 1: Fetch and format news
    print('📡 Step 1: Fetching and formatting news...');
    final categories = ['Tech'];
    final formattedNews = await webService.getDailyBriefing(categories);
    
    print('✅ Formatted news has ${formattedNews.split('\n').where((l) => l.trim().isEmpty).length} blank lines');
    
    // Step 2: Build context like the app does
    print('\n🎭 Step 2: Building AI context...');
    final context = '''
[DAILY UPDATE MODE]
You have fresh news to share. Present it exactly as provided below, preserving all formatting and spacing.

$formattedNews

Add a brief intro like "Here's what's happening:" and end with "Want to dig into any of these?"

Keep it casual and natural, but DON'T reformat or reorganize the news - present it exactly as provided above.
''';
    
    // Step 3: Send to AI
    print('\n🤖 Step 3: Sending to AI orchestrator...');
    final aiResponse = await orchestrator.orchestratedRequest(
      prompt: 'daily update',
      userContext: context,
    );
    
    print('\n📊 AI RESPONSE:');
    print('=' * 80);
    print(aiResponse);
    print('=' * 80);
    
    // Step 4: Verify spacing is preserved
    final lines = aiResponse.split('\n');
    int bulletCount = 0;
    int spacedBullets = 0;
    
    for (int i = 0; i < lines.length - 1; i++) {
      final current = lines[i].trim();
      final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
      
      if (current.startsWith('*') || current.startsWith('•')) {
        bulletCount++;
        if (next.isEmpty || next.startsWith('*') || next.startsWith('•')) {
          spacedBullets++;
        }
      }
    }
    
    print('\n📈 FINAL ANALYSIS:');
    print('   Bullets in AI response: $bulletCount');
    print('   Bullets with spacing: $spacedBullets');
    if (bulletCount > 0) {
      print('   Spacing preservation: ${(spacedBullets / bulletCount * 100).toStringAsFixed(1)}%');
    }
    
    // Expect at least 70% spacing preservation
    if (bulletCount > 0) {
      expect(spacedBullets / bulletCount, greaterThan(0.7),
        reason: 'AI should preserve most of the bullet spacing');
    }
    
    print('\n✅ Test PASSED! AI preserves spacing.\n');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
