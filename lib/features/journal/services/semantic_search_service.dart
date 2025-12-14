import 'package:flutter/foundation.dart';
import 'package:sable/core/memory/vector_memory_service.dart';
import 'package:sable/core/memory/unified_memory_service.dart';
import 'package:sable/core/memory/models/extracted_memory.dart';

/// Semantic Search Service for Phase 2: Memory Spine & Intelligence
/// Provides "When did I last mention X?" and related semantic search functionality
class SemanticSearchService {
  static final SemanticSearchService _instance = SemanticSearchService._internal();
  factory SemanticSearchService() => _instance;
  SemanticSearchService._internal();

  final VectorMemoryService _vectorService = VectorMemoryService();
  final UnifiedMemoryService _memoryService = UnifiedMemoryService();

  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _vectorService.initialize();
    await _memoryService.initialize();
    _initialized = true;
    
    debugPrint('✅ SemanticSearchService initialized');
  }

  /// Search memories semantically using vector similarity
  /// Returns memories ranked by relevance
  Future<List<SearchResult>> search(String query, {int limit = 10}) async {
    if (!_initialized) await initialize();
    
    final results = <SearchResult>[];

    try {
      // 1. Search cloud vector storage (Pinecone) for semantic matches
      if (_vectorService.hasPinecone) {
        final vectorMatches = await _vectorService.searchCloud(query, limit: limit);
        for (final memory in vectorMatches) {
          results.add(SearchResult(
            memory: memory,
            source: SearchSource.vector,
            relevanceScore: 0.9, // High relevance from vector search
          ));
        }
      }

      // 2. Also search local memories with keyword matching
      final localMemories = _memoryService.searchMemories(query);
      for (final memory in localMemories) {
        // Check if this memory is already in results from vector search
        if (!results.any((r) => r.memory.id == memory.id)) {
          results.add(SearchResult(
            memory: memory,
            source: SearchSource.local,
            relevanceScore: _calculateKeywordRelevance(query, memory),
          ));
        }
      }

      // Sort by relevance and limit
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      return results.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Semantic search error: $e');
      return [];
    }
  }

  /// Find the first mention of a topic
  /// Returns the oldest memory matching the query
  Future<ExtractedMemory?> findFirstMention(String topic) async {
    final results = await search(topic, limit: 100);
    if (results.isEmpty) return null;

    // Sort by date ascending (oldest first)
    results.sort((a, b) => a.memory.extractedAt.compareTo(b.memory.extractedAt));
    return results.first.memory;
  }

  /// Find the last/most recent mention of a topic
  /// Returns the newest memory matching the query
  Future<ExtractedMemory?> findLastMention(String topic) async {
    final results = await search(topic, limit: 100);
    if (results.isEmpty) return null;

    // Sort by date descending (newest first)
    results.sort((a, b) => b.memory.extractedAt.compareTo(a.memory.extractedAt));
    return results.first.memory;
  }

  /// Answer "When did I first/last mention X?" queries
  Future<String> answerWhenQuery(String query) async {
    final lowerQuery = query.toLowerCase();
    
    // Parse the query to understand intent
    final isFirst = lowerQuery.contains('first') || lowerQuery.contains('earliest');
    final isLast = lowerQuery.contains('last') || lowerQuery.contains('recent') || lowerQuery.contains('latest');
    
    // Extract the topic (rough heuristic - remove common question words)
    final topic = query
        .replaceAll(RegExp(r'when did i (first|last|most recently) (mention|talk about|write about|say)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\?'), '')
        .trim();
    
    if (topic.isEmpty) {
      return "I couldn't understand what topic you're asking about.";
    }

    ExtractedMemory? memory;
    if (isFirst) {
      memory = await findFirstMention(topic);
    } else if (isLast) {
      memory = await findLastMention(topic);
    } else {
      // Default to last mention
      memory = await findLastMention(topic);
    }

    if (memory == null) {
      return "I don't have any memories about '$topic'.";
    }

    final dateStr = _formatDate(memory.extractedAt);
    final timeAgo = _formatTimeAgo(memory.extractedAt);
    
    if (isFirst) {
      return "You first mentioned '$topic' on $dateStr ($timeAgo).\n\n\"${memory.content}\"";
    } else {
      return "You last mentioned '$topic' on $dateStr ($timeAgo).\n\n\"${memory.content}\"";
    }
  }

  /// Get related memories (memories similar to a given memory)
  Future<List<ExtractedMemory>> getRelatedMemories(ExtractedMemory memory, {int limit = 5}) async {
    final results = await search(memory.content, limit: limit + 1);
    // Filter out the original memory
    return results
        .where((r) => r.memory.id != memory.id)
        .take(limit)
        .map((r) => r.memory)
        .toList();
  }

  /// Calculate keyword-based relevance score (0.0 - 1.0)
  double _calculateKeywordRelevance(String query, ExtractedMemory memory) {
    final queryWords = query.toLowerCase().split(' ');
    final contentWords = memory.content.toLowerCase().split(' ');
    
    int matches = 0;
    for (final queryWord in queryWords) {
      if (contentWords.any((w) => w.contains(queryWord))) {
        matches++;
      }
    }
    
    // Also check tags
    for (final tag in memory.tags) {
      if (query.toLowerCase().contains(tag.toLowerCase())) {
        matches += 2; // Give extra weight to tag matches
      }
    }
    
    return (matches / queryWords.length).clamp(0.0, 1.0);
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).round()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).round()} months ago';
    return '${(diff.inDays / 365).round()} years ago';
  }
}

/// Result from semantic search
class SearchResult {
  final ExtractedMemory memory;
  final SearchSource source;
  final double relevanceScore;

  SearchResult({
    required this.memory,
    required this.source,
    required this.relevanceScore,
  });
}

/// Source of the search result
enum SearchSource {
  vector,  // From Pinecone vector search
  local,   // From local Hive keyword search
}
