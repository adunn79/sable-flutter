import 'package:flutter/services.dart';

/// Service to manage avatar asset mapping for context-aware visualization.
/// 
/// Provides paths to either "Original" (stylized/animated) or "Professional" 
/// (photorealistic) avatar variants based on the current UI context.
class AvatarAssetService {
  // Cache for asset existence checks
  static final Map<String, bool> _professionalAssetCache = {};
  
  /// List of all available archetypes
  static const List<String> archetypeIds = [
    'sable',
    'marco',
    'aeliana',
    'echo',
    'kai',
    'imani',
    'priya',
    'arjun',
    'ravi',
    'james',
  ];
  
  /// Get the appropriate avatar path based on context.
  /// 
  /// [archetypeId] - The ID of the avatar archetype (e.g., 'marco', 'sable')
  /// [professional] - Whether to use the professional/photorealistic variant
  /// [fallbackToOriginal] - If true, returns original path if professional doesn't exist
  static String getAvatarPath(
    String archetypeId, {
    bool professional = false,
    bool fallbackToOriginal = true,
  }) {
    final normalizedId = archetypeId.toLowerCase();
    
    if (professional) {
      final professionalPath = 'assets/images/archetypes/${normalizedId}_professional.png';
      
      // If we should fallback and professional doesn't exist, use original
      if (fallbackToOriginal && !hasProfessionalVariant(normalizedId)) {
        return 'assets/images/archetypes/$normalizedId.png';
      }
      
      return professionalPath;
    }
    
    return 'assets/images/archetypes/$normalizedId.png';
  }
  
  /// Check if a professional variant exists for the given archetype.
  /// 
  /// This checks the cache first, then attempts to verify the asset exists.
  static bool hasProfessionalVariant(String archetypeId) {
    final normalizedId = archetypeId.toLowerCase();
    
    // Check cache first
    if (_professionalAssetCache.containsKey(normalizedId)) {
      return _professionalAssetCache[normalizedId]!;
    }
    
    // All main archetypes have professional variants
    final mainArchetypes = ['sable', 'marco', 'aeliana', 'echo', 'kai', 'imani', 'priya', 'arjun', 'ravi', 'james'];
    final exists = mainArchetypes.contains(normalizedId);
    
    _professionalAssetCache[normalizedId] = exists;
    return exists;
  }
  
  /// Preload and verify which professional assets actually exist.
  /// 
  /// Call this during app initialization to populate the cache.
  static Future<void> preloadAssetCache() async {
    for (final id in archetypeIds) {
      final professionalPath = 'assets/images/archetypes/${id}_professional.png';
      try {
        await rootBundle.load(professionalPath);
        _professionalAssetCache[id] = true;
      } catch (e) {
        _professionalAssetCache[id] = false;
      }
    }
  }
  
  /// Get the display name for an archetype
  static String getArchetypeName(String archetypeId) {
    switch (archetypeId.toLowerCase()) {
      case 'sable':
        return 'Sable';
      case 'marco':
        return 'Marco';
      case 'aeliana':
        return 'Aeliana';
      case 'echo':
        return 'Echo';
      case 'kai':
        return 'Kai';
      case 'imani':
        return 'Imani';
      case 'priya':
        return 'Priya';
      case 'arjun':
        return 'Arjun';
      case 'ravi':
        return 'Ravi';
      case 'james':
        return 'James';
      default:
        return archetypeId;
    }
  }
}
