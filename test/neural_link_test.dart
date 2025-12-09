
import 'package:flutter_test/flutter_test.dart';
import 'package:sable/core/ai/neural_link_service.dart';
// We only need basic logic testing here. 
// Since NeuralLinkService instantiates providers internally, 
// a true unit test would require dependency injection of those providers.
// For now, we will just test the data structures and enum logic,
// and rely on manual verification for actual API hits.

void main() {
  group('NeuralLinkService Logic', () {
    test('NeuralNodeReport stores correct values', () {
      final report = NeuralNodeReport(
        providerId: 'Test',
        status: NeuralStatus.online,
        latencyMs: 100,
      );
      
      expect(report.isHealthy, true);
      expect(report.providerId, 'Test');
    });

    test('NeuralNodeReport detects errors', () {
      final report = NeuralNodeReport(
        providerId: 'Test',
        status: NeuralStatus.error,
        latencyMs: 0,
        errorMessage: 'Timeout',
      );
      
      expect(report.isHealthy, false);
      expect(report.errorMessage, 'Timeout');
    });
  });
}
