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
      _pineconeApiKey = pineconeKey.isNotEmpty ? pineconeKey : null;
      // Note: Pinecone index host should be in AppConfig too, but for now keep empty check
      if (pineconeKey.isEmpty) {
        debugPrint('⚠️ VectorMemoryService: No Pinecone key, local mode only');
      }

      _isInitialized = true;
      debugPrint('✅ VectorMemoryService initialized (Gemini: true, Pinecone: ${pineconeKey.isNotEmpty})');
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
    if (!_isInitialized) return;

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
        debugPrint('☁️ Vector Memory Upserted: ${memory.content.substring(0, 10)}...');
      } else {
        debugPrint('⚠️ Pinecone Upsert Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Vector Upsert Error: $e');
    }
  }

  /// Search for similar memories in cloud
  Future<List<ExtractedMemory>> searchCloud(String query, {int limit = 5}) async {
    if (!_isInitialized) return [];

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
        // Note: Missing some fields like sourceMessageId which aren't crucial for recall
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
            sourceMessageId: null, // Lost in vector transition, rarely needed
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
}
