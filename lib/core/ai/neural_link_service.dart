import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/core/ai/providers/anthropic_provider.dart';
import 'package:sable/core/ai/providers/gemini_provider.dart';
import 'package:sable/core/ai/providers/openai_provider.dart';
import 'package:sable/core/ai/providers/grok_provider.dart';
import 'package:sable/core/ai/providers/deepseek_provider.dart';

/// Status of a neural link connection
enum NeuralStatus {
  online,
  offline,
  highLatency,
  error,
}

/// Detailed report for a single model
class NeuralNodeReport {
  final String providerId;
  final NeuralStatus status;
  final int latencyMs;
  final String? errorMessage;

  const NeuralNodeReport({
    required this.providerId,
    required this.status,
    required this.latencyMs,
    this.errorMessage,
  });

  bool get isHealthy => status == NeuralStatus.online;
}

/// Service to monitor the health of the 5-Model Brain
class NeuralLinkService {
  final AnthropicProvider _anthropic = AnthropicProvider();
  final GeminiProvider _gemini = GeminiProvider();
  final OpenAiProvider _openai = OpenAiProvider();
  final GrokProvider _grok = GrokProvider();
  final DeepSeekProvider _deepseek = DeepSeekProvider();

  // SPEED: Cache results for 2 minutes
  List<NeuralNodeReport>? _cachedResults;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 2);

  /// Pings all 5 models with a lightweight "Hello" packet
  /// Uses cached results if available and fresh (< 2 min old)
  Future<List<NeuralNodeReport>> checkAllConnections({bool forceRefresh = false}) async {
    // Return cached results if fresh
    if (!forceRefresh && _cachedResults != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedResults!;
      }
    }

    // SPEED: Use fastest models for ping (not production models)
    final results = await Future.wait([
      _pingProvider('Claude (Personality)', _anthropic, 'claude-3-haiku-20240307'),
      _pingProvider('Gemini (Agentic)', _gemini, 'gemini-2.0-flash'),
      _pingProvider('GPT-4o (Logic)', _openai, 'gpt-4o-mini'),
      _pingProvider('Grok (Realist)', _grok, 'grok-3'), // Updated: grok-beta deprecated, use grok-3
      _pingProvider('DeepSeek (Coding)', _deepseek, 'deepseek-chat'),
    ]);

    // Cache results
    _cachedResults = results;
    _cacheTime = DateTime.now();

    return results;
  }

  Future<NeuralNodeReport> _pingProvider(String name, dynamic provider, String modelId) async {
    final stopwatch = Stopwatch()..start();
    try {
      // SPEED: Add 5-second timeout to fail fast
      await provider.generateResponse(
        prompt: "ping",
        systemPrompt: "Reply with 'pong' only.",
        modelId: modelId,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('Timeout');
      });
      
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      
      return NeuralNodeReport(
        providerId: name,
        status: ms > 2000 ? NeuralStatus.highLatency : NeuralStatus.online,
        latencyMs: ms,
      );
    } catch (e) {
      stopwatch.stop();
      return NeuralNodeReport(
        providerId: name,
        status: NeuralStatus.error,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }
}

final neuralLinkServiceProvider = Provider<NeuralLinkService>((ref) {
  return NeuralLinkService();
});

