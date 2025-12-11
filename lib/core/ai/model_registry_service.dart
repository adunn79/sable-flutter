import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model roles for semantic mapping (what we need, not specific model names)
enum ModelRole {
  fast,           // Quick responses, routing decisions
  smart,          // Complex reasoning, analysis
  coding,         // Code generation and debugging
  vision,         // Image understanding
  creative,       // Creative writing, personality
  realist,        // Unfiltered, direct responses
  embedding,      // Text embeddings
  imageGen,       // Image generation
}

/// AI Provider enumeration
enum AIProvider {
  openai,
  anthropic,
  google,
  xai,
  deepseek,
}

/// Model info from provider API
class ModelInfo {
  final String id;
  final String? displayName;
  final AIProvider provider;
  final DateTime? createdAt;
  final bool? isAvailable;
  final int? contextWindow;
  final List<String> capabilities;
  
  ModelInfo({
    required this.id,
    this.displayName,
    required this.provider,
    this.createdAt,
    this.isAvailable = true,
    this.contextWindow,
    this.capabilities = const [],
  });
  
  factory ModelInfo.fromOpenAI(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      provider: AIProvider.openai,
      createdAt: json['created'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((json['created'] as int) * 1000)
          : null,
    );
  }
  
  factory ModelInfo.fromAnthropic(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      provider: AIProvider.anthropic,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
  
  factory ModelInfo.fromXAI(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      provider: AIProvider.xai,
      createdAt: json['created'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['created'] as int) * 1000)
          : null,
    );
  }
  
  @override
  String toString() => '$provider:$id';
}

/// Role-to-model mapping with fallbacks
class RoleMapping {
  final ModelRole role;
  final List<String> preferredModels; // Ordered by preference
  final AIProvider provider;
  
  const RoleMapping({
    required this.role,
    required this.preferredModels,
    required this.provider,
  });
}

/// Dynamic Model Registry Service
/// Fetches available models at startup and provides fallback resolution
class ModelRegistryService {
  static ModelRegistryService? _instance;
  static ModelRegistryService get instance => _instance ??= ModelRegistryService._();
  
  ModelRegistryService._();
  
  // Cached available models per provider
  final Map<AIProvider, List<ModelInfo>> _availableModels = {};
  
  // Active model for each role (resolved)
  final Map<ModelRole, String> _activeModels = {};
  
  // Last refresh time
  DateTime? _lastRefresh;
  
  // Default role mappings with fallbacks (ordered by preference)
  static const List<RoleMapping> _defaultMappings = [
    // Fast models for routing/quick tasks
    RoleMapping(
      role: ModelRole.fast,
      preferredModels: ['gemini-2.0-flash', 'gemini-1.5-flash', 'gpt-4o-mini', 'gpt-3.5-turbo'],
      provider: AIProvider.google,
    ),
    // Smart models for complex reasoning
    RoleMapping(
      role: ModelRole.smart,
      preferredModels: ['o1', 'o1-preview', 'gpt-4o', 'gpt-4-turbo'],
      provider: AIProvider.openai,
    ),
    // Coding models
    RoleMapping(
      role: ModelRole.coding,
      preferredModels: ['deepseek-chat', 'deepseek-coder', 'gpt-4o'],
      provider: AIProvider.deepseek,
    ),
    // Vision models
    RoleMapping(
      role: ModelRole.vision,
      preferredModels: ['gpt-4o', 'gpt-4-vision-preview', 'gemini-2.0-flash'],
      provider: AIProvider.openai,
    ),
    // Creative/Personality models
    RoleMapping(
      role: ModelRole.creative,
      preferredModels: ['claude-3-5-sonnet-latest', 'claude-3-sonnet-20240229', 'claude-3-haiku-20240307'],
      provider: AIProvider.anthropic,
    ),
    // Realist models (xAI Grok)
    RoleMapping(
      role: ModelRole.realist,
      preferredModels: ['grok-3', 'grok-4', 'grok-4-fast-reasoning', 'grok-2'],
      provider: AIProvider.xai,
    ),
  ];
  
  // API endpoints
  static const _endpoints = {
    AIProvider.openai: 'https://api.openai.com/v1/models',
    AIProvider.anthropic: 'https://api.anthropic.com/v1/models',
    AIProvider.xai: 'https://api.x.ai/v1/models',
    AIProvider.deepseek: 'https://api.deepseek.com/v1/models',
    AIProvider.google: null, // Uses different SDK
  };
  
  /// Initialize registry and fetch available models
  Future<void> initialize() async {
    debugPrint('🧠 ModelRegistry: Initializing...');
    
    // Load cached models first for instant startup
    await _loadCachedModels();
    
    // Refresh in background
    _refreshModelsInBackground();
    
    // Resolve default models
    _resolveActiveModels();
    
    debugPrint('🧠 ModelRegistry: Initialized with ${_activeModels.length} role mappings');
  }
  
  /// Get the best available model for a role
  String getModelForRole(ModelRole role) {
    return _activeModels[role] ?? _getFallbackModel(role);
  }
  
  /// Get model by provider with auto-fallback
  String getModel(AIProvider provider, List<String> preferredModels) {
    final available = _availableModels[provider] ?? [];
    final availableIds = available.map((m) => m.id).toSet();
    
    // Find first available preferred model
    for (final modelId in preferredModels) {
      // Check exact match
      if (availableIds.contains(modelId)) {
        return modelId;
      }
      // Check prefix match (e.g., 'gpt-4o' matches 'gpt-4o-2024-08-06')
      final match = availableIds.firstWhere(
        (id) => id.startsWith(modelId) || modelId.startsWith(id),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        return match;
      }
    }
    
    // Return first preferred as fallback (API will error if unavailable)
    debugPrint('⚠️ ModelRegistry: No available match for $preferredModels, using ${preferredModels.first}');
    return preferredModels.first;
  }
  
  /// Check if a specific model is available
  bool isModelAvailable(AIProvider provider, String modelId) {
    final available = _availableModels[provider] ?? [];
    return available.any((m) => m.id == modelId || m.id.startsWith(modelId));
  }
  
  /// Get all available models for a provider
  List<ModelInfo> getAvailableModels(AIProvider provider) {
    return _availableModels[provider] ?? [];
  }
  
  /// Force refresh models from APIs
  Future<void> refreshModels() async {
    await _fetchAllModels();
    _resolveActiveModels();
    await _saveCachedModels();
  }
  
  // ==================== PRIVATE METHODS ====================
  
  void _refreshModelsInBackground() {
    // Don't block UI, refresh in background
    Future.microtask(() async {
      try {
        await _fetchAllModels();
        _resolveActiveModels();
        await _saveCachedModels();
      } catch (e) {
        debugPrint('🧠 ModelRegistry: Background refresh error: $e');
      }
    });
  }
  
  Future<void> _fetchAllModels() async {
    debugPrint('🧠 ModelRegistry: Fetching available models...');
    
    // Fetch from all providers in parallel
    await Future.wait([
      _fetchProviderModels(AIProvider.openai),
      _fetchProviderModels(AIProvider.anthropic),
      _fetchProviderModels(AIProvider.xai),
      _fetchProviderModels(AIProvider.deepseek),
    ]);
    
    _lastRefresh = DateTime.now();
    debugPrint('🧠 ModelRegistry: Fetched models from ${_availableModels.keys.length} providers');
  }
  
  Future<void> _fetchProviderModels(AIProvider provider) async {
    final endpoint = _endpoints[provider];
    if (endpoint == null) return;
    
    final apiKey = _getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('🧠 ModelRegistry: No API key for $provider');
      return;
    }
    
    try {
      final headers = _getHeaders(provider, apiKey);
      final response = await http.get(Uri.parse(endpoint), headers: headers)
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = <ModelInfo>[];
        
        for (final modelJson in (data['data'] as List? ?? [])) {
          try {
            final model = _parseModel(provider, modelJson as Map<String, dynamic>);
            models.add(model);
          } catch (e) {
            // Skip malformed model entries
          }
        }
        
        _availableModels[provider] = models;
        debugPrint('🧠 ModelRegistry: $provider has ${models.length} models');
      } else {
        debugPrint('🧠 ModelRegistry: $provider returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🧠 ModelRegistry: Error fetching $provider: $e');
    }
  }
  
  Map<String, String> _getHeaders(AIProvider provider, String apiKey) {
    switch (provider) {
      case AIProvider.openai:
        return {'Authorization': 'Bearer $apiKey'};
      case AIProvider.anthropic:
        return {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        };
      case AIProvider.xai:
        return {'Authorization': 'Bearer $apiKey'};
      case AIProvider.deepseek:
        return {'Authorization': 'Bearer $apiKey'};
      default:
        return {};
    }
  }
  
  String? _getApiKey(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return dotenv.env['OPENAI_API_KEY'];
      case AIProvider.anthropic:
        return dotenv.env['ANTHROPIC_API_KEY'];
      case AIProvider.xai:
        return dotenv.env['GROK_API_KEY'];
      case AIProvider.deepseek:
        return dotenv.env['DEEPSEEK_API_KEY'];
      default:
        return null;
    }
  }
  
  ModelInfo _parseModel(AIProvider provider, Map<String, dynamic> json) {
    switch (provider) {
      case AIProvider.openai:
        return ModelInfo.fromOpenAI(json);
      case AIProvider.anthropic:
        return ModelInfo.fromAnthropic(json);
      case AIProvider.xai:
        return ModelInfo.fromXAI(json);
      default:
        return ModelInfo(id: json['id'] as String, provider: provider);
    }
  }
  
  void _resolveActiveModels() {
    for (final mapping in _defaultMappings) {
      final modelId = getModel(mapping.provider, mapping.preferredModels);
      _activeModels[mapping.role] = modelId;
      debugPrint('🧠 ModelRegistry: ${mapping.role.name} → $modelId');
    }
  }
  
  String _getFallbackModel(ModelRole role) {
    // Hardcoded fallbacks if registry not initialized
    const fallbacks = {
      ModelRole.fast: 'gemini-2.0-flash',
      ModelRole.smart: 'gpt-4o',
      ModelRole.coding: 'deepseek-chat',
      ModelRole.vision: 'gpt-4o',
      ModelRole.creative: 'claude-3-haiku-20240307',
      ModelRole.realist: 'grok-3',
    };
    return fallbacks[role] ?? 'gpt-4o-mini';
  }
  
  Future<void> _loadCachedModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('model_registry_cache');
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        
        // Parse cached models
        for (final entry in data.entries) {
          final provider = AIProvider.values.firstWhere(
            (p) => p.name == entry.key,
            orElse: () => AIProvider.openai,
          );
          final models = (entry.value as List)
              .map((m) => ModelInfo(
                    id: m['id'] as String,
                    provider: provider,
                  ))
              .toList();
          _availableModels[provider] = models;
        }
        
        debugPrint('🧠 ModelRegistry: Loaded cached models');
      }
    } catch (e) {
      debugPrint('🧠 ModelRegistry: Cache load error: $e');
    }
  }
  
  Future<void> _saveCachedModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};
      
      for (final entry in _availableModels.entries) {
        data[entry.key.name] = entry.value.map((m) => {'id': m.id}).toList();
      }
      
      await prefs.setString('model_registry_cache', jsonEncode(data));
      debugPrint('🧠 ModelRegistry: Saved ${_availableModels.length} providers to cache');
    } catch (e) {
      debugPrint('🧠 ModelRegistry: Cache save error: $e');
    }
  }
}
