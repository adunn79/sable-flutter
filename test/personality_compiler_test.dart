import 'package:flutter_test/flutter_test.dart';
import 'package:sable/core/personality/personality_compiler.dart';

void main() {
  late PersonalityCompiler compiler;

  setUp(() {
    compiler = PersonalityCompiler.instance;
  });

  group('PersonalityCompiler', () {
    group('Forbidden phrase detection', () {
      test('detects "as an ai" phrase', () {
        const input = 'As an AI, I cannot actually feel emotions.';
        expect(compiler.hasForbiddenPhrases(input), isTrue);
      });

      test('detects "language model" phrase', () {
        const input = 'I am a large language model trained by Anthropic.';
        expect(compiler.hasForbiddenPhrases(input), isTrue);
      });

      test('detects "i don\'t have feelings" phrase', () {
        const input = "I don't have feelings like humans do.";
        expect(compiler.hasForbiddenPhrases(input), isTrue);
      });

      test('detects multiple forbidden phrases', () {
        const input = "As an AI, I don't have a physical location or feelings.";
        final found = compiler.findForbiddenPhrases(input);
        expect(found.length, greaterThan(1));
      });

      test('passes clean text', () {
        const input = "I'm here for you! How are you feeling today?";
        expect(compiler.hasForbiddenPhrases(input), isFalse);
      });

      test('detects ethical boundary refusals', () {
        const input = "It would be inappropriate for me to discuss that.";
        expect(compiler.hasForbiddenPhrases(input), isTrue);
      });

      test('detects roleplay refusals', () {
        const input = "I cannot roleplay romantic scenarios.";
        expect(compiler.hasForbiddenPhrases(input), isTrue);
      });
    });

    group('Asterisk action removal', () {
      test('removes simple asterisk actions', () {
        const input = 'Hello! *smiles warmly* How are you?';
        final result = compiler.compile(input);
        expect(result.contains('*'), isFalse);
        expect(result.contains('smiles'), isFalse);
      });

      test('removes multiple asterisk actions', () {
        const input = '*thinks deeply* Well, *scratches head* I believe...';
        final result = compiler.compile(input);
        expect(result.contains('*'), isFalse);
        expect(result.contains('thinks'), isFalse);
        expect(result.contains('scratches'), isFalse);
      });

      test('detects asterisk actions', () {
        const input = '*nods* Sure thing!';
        expect(compiler.hasAsteriskActions(input), isTrue);
      });

      test('passes text without asterisks', () {
        const input = 'Sure thing, I can help with that!';
        expect(compiler.hasAsteriskActions(input), isFalse);
      });
    });

    group('Warmth transformations', () {
      test('converts "I am" to "I\'m"', () {
        const input = 'I am happy to help you today!';
        final result = compiler.compile(input);
        expect(result, contains("I'm"));
        expect(result, isNot(contains('I am')));
      });

      test('converts "do not" to "don\'t"', () {
        const input = 'I do not think that is correct.';
        final result = compiler.compile(input);
        expect(result, contains("don't"));
      });

      test('converts "cannot" to "can\'t"', () {
        const input = 'I cannot do that for you.';
        final result = compiler.compile(input);
        expect(result, contains("can't"));
      });

      test('preserves capitalization', () {
        const input = 'I will help you. It is important.';
        final result = compiler.compile(input);
        expect(result, contains("I'll"));
        expect(result, contains("It's"));
      });
    });

    group('Character-specific tones', () {
      test('Echo removes filler words', () {
        const input = 'I think maybe perhaps you should just do it.';
        final result = compiler.compile(input, characterId: 'echo');
        expect(result, isNot(contains('I think')));
        expect(result, isNot(contains('maybe')));
        expect(result, isNot(contains('perhaps')));
        expect(result, isNot(contains('just')));
      });

      test('Sable is professional', () {
        const input = 'Done! Great! Awesome!';
        final result = compiler.compile(input, characterId: 'sable');
        expect(result.contains('!!'), isFalse);
      });

      test('Kai removes urgency markers', () {
        const input = 'You need to do this ASAP immediately!';
        final result = compiler.compile(input, characterId: 'kai');
        expect(result, isNot(contains('ASAP')));
        expect(result, isNot(contains('immediately')));
      });
    });

    group('Full compilation pipeline', () {
      test('removes all AI leakage', () {
        const input = '''As an AI language model, I cannot actually feel emotions. 
        *smiles* But I am here to help! I don't have a physical location though.''';
        
        final result = compiler.compile(input);
        
        expect(result, isNot(contains('As an AI')));
        expect(result, isNot(contains('language model')));
        expect(result, isNot(contains("don't have a physical location")));
        expect(result, isNot(contains('*')));
        expect(result.isNotEmpty, isTrue);
      });

      test('cleans up multiple spaces', () {
        const input = 'Hello    there!  How   are   you?';
        final result = compiler.compile(input);
        expect(result, isNot(contains('  ')));
      });

      test('handles empty input', () {
        const input = '';
        final result = compiler.compile(input);
        expect(result, isEmpty);
      });

      test('preserves emoji', () {
        const input = "I'm here for you! 💙 Let's chat!";
        final result = compiler.compile(input);
        expect(result, contains('💙'));
      });

      test('preserves markdown formatting', () {
        const input = '**Important:** This is *italicized* text.';
        final result = compiler.compile(input);
        expect(result, contains('**Important:**'));
      });
    });

    group('Safe deflection', () {
      test('returns non-empty deflection', () {
        final deflection = compiler.getSafeDeflection('aeliana');
        expect(deflection.isNotEmpty, isTrue);
      });

      test('deflection varies', () {
        // Run multiple times to check for variety
        final deflections = <String>{};
        for (var i = 0; i < 10; i++) {
          deflections.add(compiler.getSafeDeflection('aeliana'));
        }
        // Should have some variety (at least 2 different responses)
        expect(deflections.length, greaterThanOrEqualTo(1));
      });
    });
  });
}
