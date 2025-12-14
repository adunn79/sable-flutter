import 'dart:convert';
import 'package:sable/src/config/app_config.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sable/core/memory/models/extracted_memory.dart';

/// Service for handling Vector Cloud Memory (Pinecone + Gemini)
/// Provides "Cold Storage" / Infinite Recall capabilities.
class VectorMemoryService {
  static final VectorMemoryService _instance = VectorMemoryService._internal();
  factory VectorMemoryService() => _instance;
  VectorMemoryService._internal();

  GenerativeModel? _embeddingModel;
  String? _pineconeApiKey;
  String? _pineconeIndexHost;
  bool _isInitialized = false;
  bool _hasPinecone = false;

  /// Check if Pinecone is available
  bool get hasPinecone => _hasPinecone;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use AppConfig which safely handles uninitialized dotenv
      final geminiKey = AppConfig.googleKey;
      if (geminiKey.isEmpty) {
        debugPrint('⚠️ VectorMemoryService: No Gemini API key, skipping');
        return;
      }
      
      _embeddingModel = GenerativeModel(
        model: 'text-embedding-004', // Latest stable embedding model
        apiKey: geminiKey,
      );

      final pineconeKey = AppConfig.pineconeKey;
      final pineconeHost = AppConfig.pineconeHost;
      
      if (pineconeKey.isNotEmpty && pineconeHost.isNotEmpty) {
        _pineconeApiKey = pineconeKey;
        _pineconeIndexHost = pineconeHost;
        _hasPinecone = true;
        debugPrint('✅ VectorMemoryService: Pinecone enabled at $pineconeHost');
      } else {
        debugPrint('⚠️ VectorMemoryService: No Pinecone config, local mode only');
      }

      _isInitialized = true;
      debugPrint('✅ VectorMemoryService initialized (Gemini: true, Pinecone: $_hasPinecone)');
    } catch (e) {
      debugPrint('❌ VectorMemoryService init error: $e');
    }
  }

  /// Generate embeddings for text using Gemini
  Future<List<double>?> _getEmbeddings(String text) async {
    if (!_isInitialized || _embeddingModel == null) return null;

    try {
      final content = Content.text(text);
      final result = await _embeddingModel!.embedContent(content);
      return result.embedding.values;
    } catch (e) {
      debugPrint('❌ Embedding error: $e');
      return null;
    }
  }

  /// Upsert memory to Pinecone
  Future<void> upsertToCloud(ExtractedMemory memory) async {
    if (!_isInitialized || !_hasPinecone) return;

    try {
      // 1. Generate Embedding
      final embedding = await _getEmbeddings(memory.content);
      if (embedding == null) return;

      // 2. Prepare Payload
      final url = Uri.parse('$_pineconeIndexHost/vectors/upsert');
      final payload = {
        'vectors': [
          {
            'id': memory.id,
            'values': embedding,
            'metadata': {
              'content': memory.content,
              'category': memory.category.name,
              'extractedAt': memory.extractedAt.toIso8601String(),
              'importance': memory.importance,
              'tags': memory.tags.join(','),
            }
          }
        ]
      };

      // 3. Send to Pinecone
      final response = await http.post(
        url,
        headers: {
          'Api-Key': _pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('☁️ Vector Memory Upserted: ${memory.content.substring(0, 10.clamp(0, memory.content.length))}...');
      } else {
        debugPrint('⚠️ Pinecone Upsert Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Vector Upsert Error: $e');
    }
  }

  /// Search for similar memories in cloud
  Future<List<ExtractedMemory>> searchCloud(String query, {int limit = 5}) async {
    if (!_isInitialized || !_hasPinecone) return [];

    try {
      // 1. Generate Query Embedding
      final embedding = await _getEmbeddings(query);
      if (embedding == null) return [];

      // 2. Query Pinecone
      final url = Uri.parse('$_pineconeIndexHost/query');
      final payload = {
        'vector': embedding,
        'topK': limit,
        'includeMetadata': true,
      };

      final response = await http.post(
        url,
        headers: {
          'Api-Key': _pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matches = data['matches'] as List;
        
        // 3. Convert back to ExtractedMemory objects (Reconstructed from metadata)
        return matches.map<ExtractedMemory>((match) {
          final metadata = match['metadata'];
          return ExtractedMemory(
            id: match['id'],
            content: metadata['content'] ?? '',
            category: MemoryCategory.values.firstWhere(
                (e) => e.name == metadata['category'], 
                orElse: () => MemoryCategory.misc
            ),
            extractedAt: DateTime.tryParse(metadata['extractedAt'] ?? '') ?? DateTime.now(),
            sourceMessageId: null,
            tags: (metadata['tags'] as String?)?.split(',') ?? [],
            importance: (metadata['importance'] as num?)?.toInt() ?? 1,
          );
        }).toList();
      } else {
        debugPrint('⚠️ Pinecone Query Failed (${response.statusCode}): ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Vector Search Error: $e');
      return [];
    }
  }

  // ========== PHASE 2: DELETION METHODS ==========

  /// Delete a specific memory by ID
  Future<bool> deleteById(String memoryId) async {
    if (!_isInitialized || !_hasPinecone) return false;

    try {
      final url = Uri.parse('$_pineconeIndexHost/vectors/delete');
      final payload = {
        'ids': [memoryId],
      };

      final response = await http.post(
        url,
        headers: {
          'Api-Key': _pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('🗑️ Vector Memory Deleted: $memoryId');
        return true;
      } else {
        debugPrint('⚠️ Pinecone Delete Failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Vector Delete Error: $e');
      return false;
    }
  }

  /// Delete multiple memories by IDs
  Future<bool> deleteByIds(List<String> memoryIds) async {
    if (!_isInitialized || !_hasPinecone || memoryIds.isEmpty) return false;

    try {
      final url = Uri.parse('$_pineconeIndexHost/vectors/delete');
      final payload = {
        'ids': memoryIds,
      };

      final response = await http.post(
        url,
        headers: {
          'Api-Key': _pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('🗑️ Vector Memories Deleted: ${memoryIds.length} items');
        return true;
      } else {
        debugPrint('⚠️ Pinecone Bulk Delete Failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Vector Bulk Delete Error: $e');
      return false;
    }
  }

  /// Delete all memories (use with caution!)
  Future<bool> deleteAll() async {
    if (!_isInitialized || !_hasPinecone) return false;

    try {
      final url = Uri.parse('$_pineconeIndexHost/vectors/delete');
      final payload = {
        'deleteAll': true,
      };

      final response = await http.post(
        url,
        headers: {
          'Api-Key': _pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('🗑️ All Vector Memories Deleted');
        return true;
      } else {
        debugPrint('⚠️ Pinecone Delete All Failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Vector Delete All Error: $e');
      return false;
    }
  }

  /// Delete memories by metadata filter (e.g., by date range)
  /// Note: Pinecone requires specific index configurations for metadata filtering on delete
  /// This is a workaround that queries first, then deletes by ID
  Future<int> deleteAfter(DateTime cutoff) async {
    if (!_isInitialized || !_hasPinecone) return 0;

    try {
      // Pinecone doesn't support date-based deletion directly
      // We need to query with a dummy vector and filter by metadata
      // This is expensive but necessary for time-slice deletion
      
      debugPrint('🔍 Searching for memories after ${cutoff.toIso8601String()}...');
      
      // Create a simple query to find all recent memories
      // We'll use a generic embedding and rely on metadata filtering
      final dummyEmbedding = await _getEmbeddings('memory recall');
      if (dummyEmbedding == null) return 0;

      final url = Uri.parse('$_pineconeIndexHost/query');
      final payload = {
        'vector': dummyEmbedding,
        'topK': 1000, // Get up to 1000 memories
        'includeMetadata': true,
        'filter': {
          'extractedAt': {'\$gte': cutoff.toIso8601String()}
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Api-Key': _pineconeApiKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matches = data['matches'] as List;
        
        if (matches.isEmpty) {
          debugPrint('✅ No memories found after cutoff');
          return 0;
        }

        // Extract IDs and delete
        final ids = matches.map<String>((m) => m['id'] as String).toList();
        await deleteByIds(ids);
        
        debugPrint('🗑️ Deleted ${ids.length} memories after ${cutoff.toIso8601String()}');
        return ids.length;
      } else {
        debugPrint('⚠️ Pinecone Query for Delete Failed: ${response.body}');
        return 0;
      }
    } catch (e) {
      debugPrint('❌ Delete After Error: $e');
      return 0;
    }
  }
}

