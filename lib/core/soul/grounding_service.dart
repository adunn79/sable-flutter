import 'package:flutter/foundation.dart';
import '../memory/unified_memory_service.dart';

/// Grounding Service - Reduce hallucinations
/// 
/// Techniques from 2024 best practices:
/// - RAG-style context injection from memories
/// - Uncertainty acknowledgment
/// - Fact verification against known data
/// - Chain-of-thought prompting instructions
class GroundingService {
  final UnifiedMemoryService memoryService;
  
  // Cached context for speed
  String? _cachedMemoryContext;
  DateTime? _lastCacheTime;
  static const _cacheExpiry = Duration(minutes: 2);
  
  GroundingService({required this.memoryService});
  
  /// Get grounded context for a user query
  Future<String> getGroundedContext(String query) async {
    final buffer = StringBuffer();
    
    // 1. Get relevant memories (RAG-style)
    final memories = await _getRelevantMemories(query);
    if (memories.isNotEmpty) {
      buffer.writeln(memories);
    }
    
    // 2. Add grounding instructions
    buffer.writeln(_getGroundingInstructions());
    
    return buffer.toString();
  }
  
  /// Get relevant memories based on query
  Future<String> _getRelevantMemories(String query) async {
    try {
      // Try vector search first (semantic similarity)
      final vectorContext = await memoryService.getVectorContext(query);
      if (vectorContext.isNotEmpty) {
        return vectorContext;
      }
      
      // Fall back to keyword search
      final memories = await memoryService.searchMemories(query);
      if (memories.isEmpty) {
        return '';
      }
      
      // Format top 5 most relevant
      final relevantMemories = memories.take(5).toList();
      final buffer = StringBuffer();
      buffer.writeln('[RELEVANT MEMORIES FROM USER HISTORY]');
      for (final memory in relevantMemories) {
        buffer.writeln('- ${memory.content}');
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Error getting memories: $e');
      return '';
    }
  }
  
  /// Get grounding instructions for the AI
  String _getGroundingInstructions() {
    return '''
[GROUNDING RULES - CRITICAL]
1. ONLY reference information from [USER PROFILE], [RELEVANT MEMORIES], or [CONVERSATION HISTORY]
2. If you don't know something about the user, ASK - don't assume or invent
3. If asked a factual question you're unsure about, say "I'm not certain, but..." or "You might want to verify this, but..."
4. Never invent specific dates, names, or events the user hasn't mentioned
5. If you remember something about the user, quote it: "You mentioned before that..."
6. When uncertain, be HONEST: "I don't have that information" is better than making it up
''';
  }
  
  /// Get uncertainty prefix based on confidence level
  String getUncertaintyPrefix(double confidence) {
    if (confidence >= 0.9) {
      return ''; // No prefix needed, high confidence
    } else if (confidence >= 0.7) {
      return 'I believe ';
    } else if (confidence >= 0.5) {
      return 'I think ';
    } else if (confidence >= 0.3) {
      return 'I\'m not certain, but ';
    } else {
      return 'I\'m really not sure about this, but ';
    }
  }
  
  /// Check if a claim can be verified against user memories
  Future<VerificationResult> verifyClaimAgainstMemory(String claim) async {
    try {
      final memories = await memoryService.searchMemories(claim);
      
      if (memories.isEmpty) {
        return VerificationResult(
          verified: false,
          confidence: 0.0,
          reason: 'No matching memories found',
        );
      }
      
      // Check for supporting evidence
      final supportingMemories = memories.where((m) {
        final content = m.content.toLowerCase();
        final claimLower = claim.toLowerCase();
        // Simple containment check - could be enhanced with semantic similarity
        return content.contains(claimLower) || 
               claimLower.contains(content.split(' ').take(3).join(' '));
      }).toList();
      
      if (supportingMemories.isNotEmpty) {
        return VerificationResult(
          verified: true,
          confidence: 0.8,
          reason: 'Found supporting memory: ${supportingMemories.first.content}',
          evidence: supportingMemories.first.content,
        );
      }
      
      return VerificationResult(
        verified: false,
        confidence: 0.3,
        reason: 'Memories found but no direct match',
      );
    } catch (e) {
      return VerificationResult(
        verified: false,
        confidence: 0.0,
        reason: 'Error during verification: $e',
      );
    }
  }
  
  /// Prefetch common context for speed
  Future<void> prefetch() async {
    if (_cachedMemoryContext != null && 
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheExpiry) {
      return; // Cache still valid
    }
    
    try {
      final memoryContext = await memoryService.getMemoryContext();
      _cachedMemoryContext = memoryContext;
      _lastCacheTime = DateTime.now();
      debugPrint('📚 Grounding context prefetched');
    } catch (e) {
      debugPrint('Error prefetching grounding context: $e');
    }
  }
  
  /// Get chain-of-thought instructions for complex queries
  String getChainOfThoughtInstructions(String query) {
    // Detect if query needs step-by-step reasoning
    final needsReasoning = query.toLowerCase().contains('why') ||
        query.toLowerCase().contains('how should') ||
        query.toLowerCase().contains('what if') ||
        query.toLowerCase().contains('help me decide') ||
        query.toLowerCase().contains('pros and cons');
    
    if (!needsReasoning) return '';
    
    return '''
[REASONING APPROACH]
For this question, think step by step:
1. First, identify what the user is really asking
2. Consider what you know from their history
3. Think through the key factors
4. Arrive at a thoughtful response
Be transparent about your reasoning process where helpful.
''';
  }
}

/// Result of fact verification against memories
class VerificationResult {
  final bool verified;
  final double confidence;
  final String reason;
  final String? evidence;
  
  VerificationResult({
    required this.verified,
    required this.confidence,
    required this.reason,
    this.evidence,
  });
}
