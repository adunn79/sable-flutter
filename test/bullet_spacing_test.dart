import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/features/web/services/web_search_service.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/src/config/app_config.dart';

/// Test to verify bullet spacing formatter works correctly
void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  test('Daily Update Bullet Spacing Test', () async {
    print('\n🧪 Testing Daily Update Bullet Spacing Formatter...\n');
    
    final container = ProviderContainer();
    final webService = container.read(webSearchServiceProvider);
    
    // Trigger a daily briefing
    final categories = ['Tech', 'Science'];
    print('📡 Fetching daily briefing...');
    
    final result = await webService.getDailyBriefing(categories);
    
    print('\n📊 RESULT LENGTH: ${result.length} characters');
    print('\n📰 FORMATTED NEWS OUTPUT:');
    print('=' * 80);
    print(result);
    print('=' * 80);
    
    // Check for proper spacing
    final lines = result.split('\n');
    int bulletCount = 0;
    int blankLineAfterBullet = 0;
    
    for (int i = 0; i < lines.length - 1; i++) {
      final currentLine = lines[i].trim();
      final nextLine = lines[i  + 1].trim();
      
      // Detect bullets: standard, formatted links, or markdown style
      bool isBullet = currentLine.startsWith('*') || 
                      currentLine.startsWith('•') ||
                      currentLine.startsWith('[•') ||
                      currentLine.startsWith('[*');
      
      // Exclude markdown headers which start with **
      if (currentLine.startsWith('**')) {
        isBullet = false;
      }
       
      if (isBullet) {
        bulletCount++;
        if (nextLine.isEmpty) {
          blankLineAfterBullet++;
        }
      }
    }
    
    print('\n📈 SPACING ANALYSIS:');
    print('   Total bullets: $bulletCount');
    print('   Bullets with blank line after: $blankLineAfterBullet');
    print('   Spacing ratio: ${blankLineAfterBullet / bulletCount * 100}%');
    
    // Expect at least 50% of bullets to have spacing
    expect(blankLineAfterBullet / bulletCount, greaterThan(0.5), 
      reason: 'Expected most bullets to have spacing after them');
    
    print('\n✅ Test PASSED! Bullet spacing is working.\n');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
