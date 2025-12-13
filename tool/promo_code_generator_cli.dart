#!/usr/bin/env dart
/// ═══════════════════════════════════════════════════════════════════════════
/// AELIANA PROMO CODE GENERATOR - ADMIN TOOL
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// This standalone CLI tool generates cryptographically signed promo codes
/// that are verified by the app and tracked in Firebase Firestore.
/// 
/// USAGE:
///   dart run tool/promo_code_generator_cli.dart --reward=pro7d --count=10
///   dart run tool/promo_code_generator_cli.dart --reward=voice200 --count=5 --campaign=launch2024
///   dart run tool/promo_code_generator_cli.dart --list-rewards
/// 
/// After generating, upload the JSON output to Firebase Console:
///   Firestore > promo_codes collection > Import
/// 
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PROMO CODE CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

/// The secret key used to sign codes - KEEP THIS SECRET!
/// The app has the same key and verifies codes match this signature
const String _appSecret = 'aeliana_promo_2024_secret_key';

/// Alphabet for code generation (no I, O, 1, 0 to avoid confusion)
const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// All available reward types with metadata
final Map<String, RewardInfo> rewardTypes = {
  // Trials
  'pro7d': RewardInfo('Pro Week Pass', '7 days of Pro tier access'),
  'pro30d': RewardInfo('Pro Month Pass', '30 days of Pro tier access'),
  'ultra7d': RewardInfo('Ultra Week Pass', '7 days of Ultra tier access'),
  
  // Voice Credits
  'voice50': RewardInfo('Voice Starter (50)', '50 ElevenLabs voice credits'),
  'voice200': RewardInfo('Voice Plus (200)', '200 ElevenLabs voice credits'),
  'voice500': RewardInfo('Voice Pro (500)', '500 ElevenLabs voice credits'),
  
  // Video Credits
  'video25': RewardInfo('Video Starter (25)', '25 video generation credits'),
  'video100': RewardInfo('Video Plus (100)', '100 video generation credits'),
  
  // Unlocks
  'lunaUnlock': RewardInfo('Luna Access', 'Permanent access to Luna in Private Space'),
  'customAvatar': RewardInfo('Avatar Forge', 'Generate 1 custom AI avatar'),
  
  // Boosts
  'streakFreeze3': RewardInfo('Streak Shield (3x)', '3 streak freeze tokens'),
  'doubleXp24h': RewardInfo('XP Doubler (24h)', '24 hours of double XP rewards'),
  
  // Content
  'archetypeEarly': RewardInfo('Early Archetype Access', 'Early access to new archetypes'),
  'themeExclusive': RewardInfo('Exclusive Theme', 'Limited edition UI theme'),
  
  // Access
  'prioritySupport30d': RewardInfo('VIP Support (30d)', '30 days of priority support'),
};

class RewardInfo {
  final String displayName;
  final String description;
  RewardInfo(this.displayName, this.description);
}

// ═══════════════════════════════════════════════════════════════════════════
// CODE GENERATION
// ═══════════════════════════════════════════════════════════════════════════

/// Generate a cryptographically signed promo code
/// The last 4 characters are a signature that the app verifies
String generateSignedCode() {
  final random = Random.secure();
  final prefix = List.generate(8, (_) => _alphabet[random.nextInt(_alphabet.length)]).join();
  final signature = _createSignature(prefix);
  return '${prefix.substring(0, 4)}-${prefix.substring(4, 8)}-$signature';
}

/// Create a 4-character signature from prefix + secret
String _createSignature(String prefix) {
  final input = '$prefix$_appSecret';
  final hash = sha256.convert(utf8.encode(input));
  final bytes = hash.bytes.sublist(0, 4);
  final sig = StringBuffer();
  for (final b in bytes) {
    sig.write(_alphabet[b % _alphabet.length]);
  }
  return sig.toString().substring(0, 4);
}

/// Verify a code has valid signature
bool verifyCodeSignature(String code) {
  final clean = code.replaceAll('-', '').toUpperCase();
  if (clean.length != 12) return false;
  final prefix = clean.substring(0, 8);
  final providedSignature = clean.substring(8, 12);
  final expectedSignature = _createSignature(prefix);
  return providedSignature == expectedSignature;
}

/// Create a Firestore document for a promo code
Map<String, dynamic> createPromoCodeDocument({
  required String code,
  required String rewardType,
  required String createdBy,
  DateTime? expiresAt,
  String? campaign,
}) {
  return {
    'code': code.toUpperCase(),
    'type': 'oneTime',          // One-time use only
    'max_uses': 1,
    'current_uses': 0,
    'reward_type': rewardType,
    'expires_at': expiresAt?.toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
    'created_by': createdBy,
    'campaign': campaign,
    'is_active': true,
    'is_signed': true,
  };
}

/// Generate multiple codes
List<Map<String, dynamic>> batchGenerate({
  required int count,
  required String rewardType,
  required String createdBy,
  DateTime? expiresAt,
  String? campaign,
}) {
  final codes = <Map<String, dynamic>>[];
  final generatedCodes = <String>{};
  
  while (codes.length < count) {
    final code = generateSignedCode();
    if (!generatedCodes.contains(code)) {
      generatedCodes.add(code);
      codes.add(createPromoCodeDocument(
        code: code,
        rewardType: rewardType,
        createdBy: createdBy,
        expiresAt: expiresAt,
        campaign: campaign,
      ));
    }
  }
  
  return codes;
}

// ═══════════════════════════════════════════════════════════════════════════
// CLI INTERFACE
// ═══════════════════════════════════════════════════════════════════════════

void main(List<String> arguments) {
  print('');
  print('╔══════════════════════════════════════════════════════════════════════════════╗');
  print('║           AELIANA PROMO CODE GENERATOR - ADMIN TOOL                         ║');
  print('╚══════════════════════════════════════════════════════════════════════════════╝');
  print('');

  // Parse arguments
  final args = <String, String>{};
  for (final arg in arguments) {
    if (arg.startsWith('--')) {
      final parts = arg.substring(2).split('=');
      if (parts.length == 2) {
        args[parts[0]] = parts[1];
      } else {
        args[parts[0]] = 'true';
      }
    }
  }

  // List rewards command
  if (args.containsKey('list-rewards') || args.containsKey('help')) {
    _printRewardTypes();
    return;
  }

  // Validate required args
  if (!args.containsKey('reward')) {
    print('ERROR: Missing --reward argument');
    print('');
    print('Usage:');
    print('  dart run tool/promo_code_generator_cli.dart --reward=pro7d --count=10');
    print('  dart run tool/promo_code_generator_cli.dart --list-rewards');
    print('');
    _printRewardTypes();
    return;
  }

  final rewardType = args['reward']!;
  if (!rewardTypes.containsKey(rewardType)) {
    print('ERROR: Unknown reward type: $rewardType');
    print('');
    _printRewardTypes();
    return;
  }

  final count = int.tryParse(args['count'] ?? '1') ?? 1;
  final campaign = args['campaign'];
  final createdBy = args['created-by'] ?? 'admin';
  final expiresIn = int.tryParse(args['expires-days'] ?? '');
  final expiresAt = expiresIn != null 
      ? DateTime.now().add(Duration(days: expiresIn))
      : null;

  // Generate codes
  print('🔐 Generating $count promo code(s)...');
  print('   Reward: ${rewardTypes[rewardType]!.displayName}');
  if (campaign != null) print('   Campaign: $campaign');
  if (expiresAt != null) print('   Expires: $expiresAt');
  print('');

  final codes = batchGenerate(
    count: count,
    rewardType: rewardType,
    createdBy: createdBy,
    expiresAt: expiresAt,
    campaign: campaign,
  );

  // Print codes
  print('═══════════════════════════════════════════════════════════════════════════');
  print('GENERATED PROMO CODES (copy for distribution):');
  print('═══════════════════════════════════════════════════════════════════════════');
  print('');
  
  for (var i = 0; i < codes.length; i++) {
    final code = codes[i]['code'];
    print('  ${(i + 1).toString().padLeft(3)}. $code  →  ${rewardTypes[rewardType]!.displayName}');
  }
  
  print('');
  print('═══════════════════════════════════════════════════════════════════════════');
  
  // Save to file
  final filename = 'promo_codes_${rewardType}_${DateTime.now().millisecondsSinceEpoch}.json';
  final file = File(filename);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'generated_at': DateTime.now().toIso8601String(),
    'reward_type': rewardType,
    'reward_name': rewardTypes[rewardType]!.displayName,
    'count': count,
    'campaign': campaign,
    'codes': codes,
  }));
  
  print('');
  print('📁 Saved to: $filename');
  print('');
  print('┌─────────────────────────────────────────────────────────────────────────────┐');
  print('│ NEXT STEPS:                                                                 │');
  print('├─────────────────────────────────────────────────────────────────────────────┤');
  print('│ 1. Go to Firebase Console > Firestore > promo_codes collection            │');
  print('│ 2. Click "Add Document" for each code                                       │');
  print('│ 3. Copy the document fields from the JSON file                              │');
  print('│                                                                             │');
  print('│ The app will verify:                                                        │');
  print('│   ✓ Code signature matches (cryptographic verification)                    │');
  print('│   ✓ Code exists in Firestore                                               │');
  print('│   ✓ Code has not been used (current_uses < 1)                              │');
  print('│   ✓ Code not already redeemed by this device                               │');
  print('│   ✓ Code not expired                                                        │');
  print('└─────────────────────────────────────────────────────────────────────────────┘');
  print('');
}

void _printRewardTypes() {
  print('AVAILABLE REWARD TYPES (15):');
  print('═══════════════════════════════════════════════════════════════════════════');
  print('');
  
  var i = 1;
  for (final entry in rewardTypes.entries) {
    print('  ${i.toString().padLeft(2)}. ${entry.key.padRight(20)} │ ${entry.value.displayName}');
    print('      ${entry.value.description}');
    print('');
    i++;
  }
  
  print('═══════════════════════════════════════════════════════════════════════════');
  print('');
  print('Example usage:');
  print('  dart run tool/promo_code_generator_cli.dart --reward=pro7d --count=10');
  print('  dart run tool/promo_code_generator_cli.dart --reward=voice200 --count=5 --campaign=launch');
  print('  dart run tool/promo_code_generator_cli.dart --reward=lunaUnlock --count=3 --expires-days=30');
  print('');
}
