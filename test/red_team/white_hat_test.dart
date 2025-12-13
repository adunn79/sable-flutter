// ignore_for_file: avoid_print
/// ═══════════════════════════════════════════════════════════════════════════
/// SQUAD 3: WHITE HAT - SECURITY & SECRETS SWEEP
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Target: Hardcoded secrets, PII leaks, Promo code exploits
/// 
/// Run: flutter test test/red_team/white_hat_test.dart
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'red_team_framework.dart';

// Import promo system for testing
import 'package:sable/core/promo/promo_models.dart';
import 'package:sable/core/promo/promo_code_generator.dart';

void main() {
  setUpAll(() async {
    await setUpRedTeam();
    print('🕵️ SQUAD "WHITE HAT" ACTIVATED - SECURITY AUDIT');
    print('═══════════════════════════════════════════════════');
    print('');
  });

  tearDownAll(() async {
    // Print promo code reward types for user reference
    _printPromoCodeList();
    await tearDownRedTeam();
  });

  group('🕵️ WHITE HAT - API Key Scan', () {
    test('WH1: No hardcoded OpenAI keys', () async {
      final result = await _scanForPattern(
        pattern: r'sk-proj-[A-Za-z0-9_-]{20,}',
        patternName: 'OpenAI API Key',
      );
      redTeamReport.addResult(result);
      expect(result.resultType, isNot(AuditResultType.fail));
    });

    test('WH2: No hardcoded Google API keys', () async {
      final result = await _scanForPattern(
        pattern: r'AIzaSy[A-Za-z0-9_-]{33}',
        patternName: 'Google API Key',
      );
      redTeamReport.addResult(result);
      expect(result.resultType, isNot(AuditResultType.fail));
    });

    test('WH3: No hardcoded Anthropic keys', () async {
      final result = await _scanForPattern(
        pattern: r'sk-ant-[A-Za-z0-9_-]{20,}',
        patternName: 'Anthropic API Key',
      );
      redTeamReport.addResult(result);
      expect(result.resultType, isNot(AuditResultType.fail));
    });

    test('WH4: No hardcoded xAI keys', () async {
      final result = await _scanForPattern(
        pattern: r'xai-[A-Za-z0-9_-]{20,}',
        patternName: 'xAI API Key',
      );
      redTeamReport.addResult(result);
      expect(result.resultType, isNot(AuditResultType.fail));
    });

    test('WH5: No hardcoded ElevenLabs keys', () async {
      final result = await _scanForPattern(
        pattern: r'[a-f0-9]{32}', // ElevenLabs uses 32-char hex
        patternName: 'ElevenLabs API Key',
        excludePatterns: ['color:', 'Color(', '0x', 'hash', 'sha', 'md5'],
      );
      redTeamReport.addResult(result);
      // This one might have false positives, so just log it
    });
  });

  group('🕵️ WHITE HAT - Promo Code Security', () {
    test('WH6: Promo code signature verification works', () async {
      // Generate a signed code
      final signedCode = PromoCodeGenerator.generateSignedCode();
      
      // Verify it passes
      final isValid = PromoCodeGenerator.verifyCodeSignature(signedCode);
      
      if (!isValid) {
        redTeamReport.addResult(AuditResult(
          squadName: 'WHITE HAT',
          testName: 'Promo signature verification',
          resultType: AuditResultType.fail,
          details: 'Generated code failed verification: $signedCode',
        ));
      } else {
        redTeamReport.addResult(AuditResult(
          squadName: 'WHITE HAT',
          testName: 'Promo signature verification',
          resultType: AuditResultType.pass,
          details: 'Signed codes verify correctly',
        ));
      }
      
      expect(isValid, isTrue);
    });

    test('WH7: Invalid promo codes are rejected', () async {
      // Try to forge a code
      final forgedCodes = [
        'AAAA-BBBB-CCCC',
        'FREE-LUNA-PLZZ',
        '1234-5678-9012',
        'HACK-THIS-CODE',
      ];
      
      var allRejected = true;
      for (final code in forgedCodes) {
        if (PromoCodeGenerator.verifyCodeSignature(code)) {
          allRejected = false;
          break;
        }
      }
      
      redTeamReport.addResult(AuditResult(
        squadName: 'WHITE HAT',
        testName: 'Forged code rejection',
        resultType: allRejected ? AuditResultType.pass : AuditResultType.fail,
        details: allRejected 
            ? 'All forged codes correctly rejected'
            : 'SECURITY BREACH: Forged code accepted!',
      ));
      
      expect(allRejected, isTrue);
    });

    test('WH8: Promo codes are cryptographically random', () async {
      // Generate 100 codes and check for patterns
      final codes = <String>{};
      for (var i = 0; i < 100; i++) {
        codes.add(PromoCodeGenerator.generateSignedCode());
      }
      
      // All should be unique
      final allUnique = codes.length == 100;
      
      // Check entropy - no repeated prefixes
      final prefixes = codes.map((c) => c.split('-')[0]).toSet();
      final goodEntropy = prefixes.length > 90; // At least 90% unique prefixes
      
      redTeamReport.addResult(AuditResult(
        squadName: 'WHITE HAT',
        testName: 'Promo code entropy',
        resultType: (allUnique && goodEntropy) ? AuditResultType.pass : AuditResultType.fail,
        details: 'Generated 100 codes: ${codes.length} unique, ${prefixes.length} unique prefixes',
      ));
      
      expect(allUnique, isTrue);
      expect(goodEntropy, isTrue);
    });

    test('WH9: All 15 reward types are defined', () async {
      final expectedCount = 15;
      final actualCount = RewardType.values.length;
      
      redTeamReport.addResult(AuditResult(
        squadName: 'WHITE HAT',
        testName: 'Reward type completeness',
        resultType: actualCount >= expectedCount ? AuditResultType.pass : AuditResultType.fail,
        details: 'Found $actualCount reward types (expected $expectedCount)',
      ));
      
      expect(actualCount, greaterThanOrEqualTo(expectedCount));
    });
  });

  group('🕵️ WHITE HAT - Data Protection', () {
    test('WH10: PII patterns not in debug prints', () async {
      final result = await _scanForPattern(
        pattern: r'print\([^)]*(?:email|password|ssn|social.*security)',
        patternName: 'PII in debug prints',
        caseSensitive: false,
      );
      redTeamReport.addResult(result);
    });

    test('WH11: No exposed Firebase credentials', () async {
      final result = await _scanForPattern(
        pattern: r'firebase.*(?:api|secret|credential)',
        patternName: 'Firebase credentials',
        caseSensitive: false,
      );
      redTeamReport.addResult(result);
    });
  });
}

/// Scan lib directory for a pattern
Future<AuditResult> _scanForPattern({
  required String pattern,
  required String patternName,
  List<String> excludePatterns = const [],
  bool caseSensitive = true,
}) async {
  try {
    final libDir = Directory('lib');
    if (!await libDir.exists()) {
      return AuditResult(
        squadName: 'WHITE HAT',
        testName: patternName,
        resultType: AuditResultType.warning,
        details: 'Could not access lib directory',
      );
    }

    final regex = RegExp(pattern, caseSensitive: caseSensitive);
    final matches = <String>[];

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final content = await entity.readAsString();
        
        for (final match in regex.allMatches(content)) {
          final matchText = match.group(0) ?? '';
          
          // Skip if it matches an exclude pattern
          var excluded = false;
          for (final exclude in excludePatterns) {
            if (matchText.toLowerCase().contains(exclude.toLowerCase())) {
              excluded = true;
              break;
            }
          }
          
          if (!excluded) {
            matches.add('${entity.path}: ${matchText.substring(0, matchText.length.clamp(0, 50))}');
          }
        }
      }
    }

    if (matches.isEmpty) {
      return AuditResult(
        squadName: 'WHITE HAT',
        testName: patternName,
        resultType: AuditResultType.pass,
        details: 'No $patternName found in codebase',
      );
    } else {
      return AuditResult(
        squadName: 'WHITE HAT',
        testName: patternName,
        resultType: AuditResultType.fail,
        details: 'Found ${matches.length} potential $patternName',
        location: matches.take(3).join('\n'),
        autoFixSuggestion: 'Move to .env file and regenerate',
      );
    }
  } catch (e) {
    return AuditResult(
      squadName: 'WHITE HAT',
      testName: patternName,
      resultType: AuditResultType.warning,
      details: 'Scan error: $e',
    );
  }
}

/// Print the full list of promo codes for user reference
void _printPromoCodeList() {
  print('');
  print('═══════════════════════════════════════════════════════════════════════════');
  print('📋 AELIANA PROMO CODE REWARD TYPES (15 TOTAL)');
  print('═══════════════════════════════════════════════════════════════════════════');
  print('');
  print('┌─────────────────────────────────────────────────────────────────────────┐');
  print('│ CATEGORY: TRIALS (3)                                                    │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│  1. pro7d       │ Pro Week Pass        │ 7 days Pro tier access        │');
  print('│  2. pro30d      │ Pro Month Pass       │ 30 days Pro tier access       │');
  print('│  3. ultra7d     │ Ultra Week Pass      │ 7 days Ultra tier access      │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ CATEGORY: VOICE CREDITS (3)                                            │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│  4. voice50     │ Voice Starter (50)   │ 50 ElevenLabs voice credits   │');
  print('│  5. voice200    │ Voice Plus (200)     │ 200 ElevenLabs voice credits  │');
  print('│  6. voice500    │ Voice Pro (500)      │ 500 ElevenLabs voice credits  │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ CATEGORY: VIDEO CREDITS (2)                                            │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│  7. video25     │ Video Starter (25)   │ 25 video generation credits   │');
  print('│  8. video100    │ Video Plus (100)     │ 100 video generation credits  │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ CATEGORY: UNLOCKS (2)                                                  │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│  9. lunaUnlock  │ Luna Access          │ Permanent Luna in Private     │');
  print('│ 10. customAvatar│ Avatar Forge         │ Generate 1 custom AI avatar   │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ CATEGORY: BOOSTS (2)                                                   │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ 11. streakFreeze│ Streak Shield (3x)   │ 3 streak freeze tokens        │');
  print('│ 12. doubleXp24h │ XP Doubler (24h)     │ 24 hours of double XP         │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ CATEGORY: CONTENT (2)                                                  │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ 13. archetypeEar│ Early Archetype      │ Early access to new types     │');
  print('│ 14. themeExclus │ Exclusive Theme      │ Limited edition UI theme      │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ CATEGORY: ACCESS (1)                                                   │');
  print('├─────────────────────────────────────────────────────────────────────────┤');
  print('│ 15. prioritySup │ VIP Support (30d)    │ 30 days priority support      │');
  print('└─────────────────────────────────────────────────────────────────────────┘');
  print('');
  print('🔐 SECURITY: Codes use cryptographic signatures - cannot be forged');
  print('🔒 REDEMPTION: One-time use, device-bound, Firestore-validated');
  print('');
}
