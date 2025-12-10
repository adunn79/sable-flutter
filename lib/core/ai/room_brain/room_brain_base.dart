import 'package:sable/core/ai/memory_spine.dart';
import 'package:sable/core/ai/tool_registry.dart';
import 'package:sable/core/ai/agent_context.dart';
import 'package:sable/core/ai/character_personality.dart';

/// Base class for all Room Brains (tab-specific AI expertise)
abstract class RoomBrain {
  final MemorySpine memorySpine;
  final ToolRegistry tools;

  RoomBrain({
    required this.memorySpine,
    required this.tools,
  });

  /// Domain of this brain (e.g., "chat", "journal", "wellness", "settings")
  String get domain;

  /// List of capabilities/tools this brain can use
  List<String> get capabilities;

  /// Main entry point: process user query with character personality overlay
  Future<String> respond({
    required String query,
    required CharacterPersonality personality,
    required AgentContext context,
  }) async {
    // 1. Understand intent and execute domain logic
    final brainResponse = await processQuery(query, context);

    // 2. If tool execution required, execute it
    if (brainResponse.requiresToolExecution && brainResponse.toolCall != null) {
      final toolName = brainResponse.toolCall!['name'] as String;
      final params = brainResponse.toolCall!['params'] as Map<String, dynamic>;

      final toolResult = await tools.execute(
        toolName,
        params,
        callingBrain: domain,
      );

      if (toolResult.success) {
        // Tool succeeded - apply personality to the result
        final expertiseResponse = toolResult.userMessage ?? toolResult.data.toString();
        return personality.applyTone(expertiseResponse);
      } else {
        // Tool failed - apply personality to error
        final errorMessage = toolResult.userMessage ?? 'Something went wrong.';
        return personality.applyTone(errorMessage);
      }
    }

    // 3. No tool required - apply personality to brain's response
    return personality.applyTone(brainResponse.content);
  }

  /// Domain-specific processing logic
  /// Subclasses implement this to handle their domain expertise
  Future<BrainResponse> processQuery(String query, AgentContext context);

  /// Helper: Check if query is related to this brain's domain
  bool canHandle(String query);
}
