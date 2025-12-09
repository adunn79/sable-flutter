
import 'package:flutter_test/flutter_test.dart';
import 'package:sable/core/ai/fact_check_service.dart';

void main() {
  group('FactCheckService Logic', () {
    test('FactCheckResult parsing', () {
      final result = FactCheckResult(
        isAccurate: true,
        correction: '',
        sources: ['Google'],
        confidenceScore: 'High',
      );
      
      expect(result.isAccurate, true);
      expect(result.confidenceScore, 'High');
    });
  });
}
