import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/room_brain/room_brain_base.dart';
import 'package:sable/core/ai/room_brain/journal_brain.dart';
import 'package:sable/core/ai/room_brain/vital_balance_brain.dart';
import 'package:sable/core/ai/room_brain/settings_brain.dart';
import 'package:sable/core/ai/agent_context.dart';
import 'package:sable/core/ai/memory_spine.dart';
import 'package:sable/core/ai/tool_registry.dart';
import 'package:sable/core/ai/character_personality.dart';

/// Brain Orchestrator - Supervisor pattern for multi-brain collaboration
/// Chat Brain can consult Journal, Vital Balance, or Settings brains for expertise
class BrainOrchestrator {
  final ChatBrain chatBrain;
  final JournalBrain? journalBrain;
  final VitalBalanceBrain? vitalBalanceBrain;
  final SettingsBrain? settingsBrain;
  
  BrainOrchestrator({
    required this.chatBrain,
    this.journalBrain,
    this.vitalBalanceBrain,
    this.settingsBrain,
  });

  /// Process query with orchestration - Chat Brain delegates to experts when needed
  Future<String> processQuery({
    required String query,
    required CharacterPersonality personality,
    required AgentContext context,
  }) async {
    debugPrint('🎭 Brain Orchestrator: Processing query');
    
    // First, check if any specialist brain can handle this better than chat
    final lowerQuery = query.toLowerCase();
    
    // Journal expertise needed?
    if (journalBrain != null && journalBrain!.canHandle(query)) {
      debugPrint('📝 Delegating to Journal Brain for expertise');
      final journalResponse = await journalBrain!.processQuery(query, context);
      
      if (journalResponse.directResponse != null) {
        // Journal brain has a direct answer - use it with personality overlay
        return await personality.applyTone(
          response: journalResponse.directResponse!,
          context: 'journaling and reflection',
        );
      }
    }
    
    // Health/wellness expertise needed?
    if (vitalBalanceBrain != null && vitalBalanceBrain!.canHandle(query)) {
      debugPrint('💓 Delegating to Vital Balance Brain for expertise');
      final healthResponse = await vitalBalanceBrain!.processQuery(query, context);
      
      if (healthResponse.directResponse != null) {
        // Health brain has a direct answer - use it with personality overlay
        return await personality.applyTone(
          response: healthResponse.directResponse!,
          context: 'health and wellness coaching',
        );
      }
    }
    
    // Settings expertise needed?
    if (settingsBrain != null && settingsBrain!.canHandle(query)) {
      debugPrint('⚙️ Delegating to Settings Brain for expertise');
      final settingsResponse = await settingsBrain!.processQuery(query, context);
      
      if (settingsResponse.directResponse != null) {
        // Settings brain has a direct answer - use it with personality overlay
        return await personality.applyTone(
          response: settingsResponse.directResponse!,
          context: 'app configuration',
        );
      }
    }
    
    // Default: Chat Brain handles it (calendar, tasks, general conversation)
    debugPrint('💬 Chat Brain handling query');
    return await chatBrain.respond(
      query: query,
      personality: personality,
      context: context,
    );
  }
  
  /// Check if query needs multi-brain collaboration
  bool needsCollaboration(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Examples of queries needing multiple brains:
    // "Track my mood and set a recovery goal" (journal + health)
    // "Journal about my workout and add it to calendar" (journal + chat)
    
    int brainInterest = 0;
    if (chatBrain.canHandle(query)) brainInterest++;
    if (journalBrain != null && journalBrain!.canHandle(query)) brainInterest++;
    if (vitalBalanceBrain != null && vitalBalanceBrain!.canHandle(query)) brainInterest++;
    if (settingsBrain != null && settingsBrain!.canHandle(query)) brainInterest++;
    
    return brainInterest > 1;
  }
}
