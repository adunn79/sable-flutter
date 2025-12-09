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

  /// Pings all 5 models with a lightweight "Hello" packet
  Future<List<NeuralNodeReport>> checkAllConnections() async {
    final results = await Future.wait([
      _pingProvider('Claude (Personality)', _anthropic, 'claude-3-haiku-20240307'),
      _pingProvider('Gemini (Agentic)', _gemini, 'gemini-2.0-flash'),
      _pingProvider('GPT-4o (Logic)', _openai, 'gpt-4o-mini'),
      _pingProvider('Grok (Realist)', _grok, 'grok-2-latest'),
      _pingProvider('DeepSeek (Coding)', _deepseek, 'deepseek-chat'),
    ]);

    return results;
  }

  Future<NeuralNodeReport> _pingProvider(String name, dynamic provider, String modelId) async {
    final stopwatch = Stopwatch()..start();
    try {
      // Send a minimal token packet
      await provider.generateResponse(
        prompt: "ping",
        systemPrompt: "Reply with 'pong' only.",
        modelId: modelId,
      );
      
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
