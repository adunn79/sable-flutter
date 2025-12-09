import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/core/memory/models/chat_message.dart';
import 'package:sable/core/memory/models/extracted_memory.dart';
import 'package:sable/core/memory/models/health_entry.dart';
import 'package:sable/core/memory/vector_memory_service.dart';


/// Unified Memory Service
/// Manages all Hive boxes for persistent, searchable AI memory
class UnifiedMemoryService {
  static const String _chatBoxName = 'chat_history_encrypted';
  static const String _memoryBoxName = 'extracted_memories_encrypted';
  static const String _healthBoxName = 'health_data';
  static const String _encryptionKeyName = 'hive_encryption_key';
  
  static const int _maxChatMessages = 1000; // Increased from 500
  
  static final UnifiedMemoryService _instance = UnifiedMemoryService._internal();
  factory UnifiedMemoryService() => _instance;
  UnifiedMemoryService._internal();
  
  Box<ChatMessage>? _chatBox;
  Box<ExtractedMemory>? _memoryBox;
  Box<HealthEntry>? _healthBox;
  final VectorMemoryService _vectorService = VectorMemoryService();
  
  bool _initialized = false;
  
  /// Initialize all memory boxes
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(MemoryCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(ExtractedMemoryAdapter());
    }
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(HealthEntryTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(HealthEntryAdapter());
    }
    
    // Open regular boxes
    final encryptionKey = await _getOrCreateEncryptionKey();
    
    // All boxes now encrypted for security
    _chatBox = await Hive.openBox<ChatMessage>(
      _chatBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    _memoryBox = await Hive.openBox<ExtractedMemory>(
      _memoryBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    
    // Health data also encrypted
    _healthBox = await Hive.openBox<HealthEntry>(
      _healthBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    
    _initialized = true;
    print('✅ UnifiedMemoryService initialized (ALL ENCRYPTED)');
    print('📂 Chat messages: ${_chatBox?.length ?? 0}');
    print('🧠 Extracted memories: ${_memoryBox?.length ?? 0}');
    print('    🔐 Health entries: ${_healthBox?.length ?? 0}');
    
    // Initialize vector service (fire and forget)
    _vectorService.initialize();
  }
  
  /// Get or create encryption key for health data
  Future<Uint8List> _getOrCreateEncryptionKey() async {
    String? keyString;
    
    // macOS and Linux may not have full secure storage support
    final useFallback = Platform.isMacOS || Platform.isLinux;
    
    if (useFallback) {
      // Use SharedPreferences on macOS/Linux (less secure but functional)
      final prefs = await SharedPreferences.getInstance();
      keyString = prefs.getString(_encryptionKeyName);
      
      if (keyString == null) {
        final key = Hive.generateSecureKey();
        keyString = base64Encode(key);
        await prefs.setString(_encryptionKeyName, keyString);
      }
    } else {
      // Use FlutterSecureStorage on iOS/Android
      const secureStorage = FlutterSecureStorage();
      
      try {
        keyString = await secureStorage.read(key: _encryptionKeyName);
        
        if (keyString == null) {
          final key = Hive.generateSecureKey();
          keyString = base64Encode(key);
          await secureStorage.write(key: _encryptionKeyName, value: keyString);
        }
      } catch (e) {
        // Fallback if secure storage fails
        print('⚠️ SecureStorage failed, using SharedPreferences fallback: $e');
        final prefs = await SharedPreferences.getInstance();
        keyString = prefs.getString(_encryptionKeyName);
        
        if (keyString == null) {
          final key = Hive.generateSecureKey();
          keyString = base64Encode(key);
          await prefs.setString(_encryptionKeyName, keyString);
        }
      }
    }
    
    return base64Decode(keyString);
  }

  
  // ============= CHAT MESSAGES =============
  
  /// Add a chat message
  Future<void> addChatMessage({
    required String message,
    required bool isUser,
    String? emotionalContext,
  }) async {
    if (_chatBox == null) await initialize();
    
    final chatMessage = ChatMessage.create(
      message: message,
      isUser: isUser,
      emotionalContext: emotionalContext,
    );
    
    await _chatBox!.add(chatMessage);
    
    // Trim to max messages if needed
    if (_chatBox!.length > _maxChatMessages) {
      final excess = _chatBox!.length - _maxChatMessages;
      for (var i = 0; i < excess; i++) {
        await _chatBox!.deleteAt(0);
      }
    }
  }
  
  /// Get all chat messages
  List<ChatMessage> getAllChatMessages() {
    return _chatBox?.values.toList() ?? [];
  }
  
  /// Get recent chat messages
  List<ChatMessage> getRecentChatMessages(int count) {
    final all = getAllChatMessages();
    if (all.length <= count) return all;
    return all.sublist(all.length - count);
  }
  
  /// Get conversation context string for AI
  String getChatContext({int messageCount = 100}) {
    final messages = getRecentChatMessages(messageCount);
    if (messages.isEmpty) return '';
    
    final buffer = StringBuffer('[RECENT CONVERSATION]\n');
    for (var msg in messages) {
      final speaker = msg.isUser ? 'User' : 'You';
      buffer.writeln('$speaker: ${msg.message}');
    }
    buffer.writeln('[END CONVERSATION]');
    
    return buffer.toString();
  }
  
  /// Clear all chat history
  Future<void> clearChatHistory() async {
    await _chatBox?.clear();
  }
  
  // ============= EXTRACTED MEMORIES =============
  
  /// Add an extracted memory with rich contextual data
  Future<void> addMemory({
    required String content,
    required MemoryCategory category,
    String? sourceMessageId,
    List<String> tags = const [],
    int importance = 3,
    // Location
    String? locationName,
    double? latitude,
    double? longitude,
    String? weather,
    // Vibe
    int? energyLevel,
    String? vibeColor,
    String? ambientDescription,
    // Social
    List<String> taggedPeople = const [],
    bool isGroupActivity = false,
    // Media
    String? nowPlayingTrack,
    String? nowPlayingService,
    List<String> attachedPhotoPaths = const [],
    // World
    String? topHeadline,
    String? onThisDay,
    // Health
    int? sleepHours,
    int? stepCount,
    // Summary
    String? oneSentenceSummary,
  }) async {
    if (_memoryBox == null) await initialize();
    
    // Check for duplicates
    final existing = _memoryBox!.values.where(
      (m) => m.content.toLowerCase() == content.toLowerCase()
    );
    if (existing.isNotEmpty) {
      print('⚠️ Memory already exists: $content');
      return;
    }
    
    final memory = ExtractedMemory.create(
      content: content,
      category: category,
      sourceMessageId: sourceMessageId,
      tags: tags,
      importance: importance,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      weather: weather,
      energyLevel: energyLevel,
      vibeColor: vibeColor,
      ambientDescription: ambientDescription,
      taggedPeople: taggedPeople,
      isGroupActivity: isGroupActivity,
      nowPlayingTrack: nowPlayingTrack,
      nowPlayingService: nowPlayingService,
      attachedPhotoPaths: attachedPhotoPaths,
      topHeadline: topHeadline,
      onThisDay: onThisDay,
      sleepHours: sleepHours,
      stepCount: stepCount,
      oneSentenceSummary: oneSentenceSummary,
    );
    
    await _memoryBox!.add(memory);
    print('🧠 Stored memory: $content');

    // Sync to Vector Cloud (Fire and Forget)
    _vectorService.upsertToCloud(memory);
  }
  
  /// Get all memories
  List<ExtractedMemory> getAllMemories() {
    return _memoryBox?.values.toList() ?? [];
  }
  
  /// Get memories by category
  List<ExtractedMemory> getMemoriesByCategory(MemoryCategory category) {
    return getAllMemories().where((m) => m.category == category).toList();
  }
  
  /// Search memories by query
  List<ExtractedMemory> searchMemories(String query) {
    return getAllMemories().where((m) => m.matchesQuery(query)).toList();
  }
  
  /// Get memory context for AI (formatted string)
  String getMemoryContext() {
    final memories = getAllMemories();
    if (memories.isEmpty) return '';
    
    final buffer = StringBuffer('[USER KNOWLEDGE]\n');
    
    for (var category in MemoryCategory.values) {
      final items = memories.where((m) => m.category == category).toList();
      if (items.isNotEmpty) {
        buffer.writeln('${_categoryLabel(category)}:');
        // Sort by importance
        items.sort((a, b) => b.importance.compareTo(a.importance));
        for (var item in items.take(10)) { // Top 10 per category
          buffer.writeln('- ${item.content}');
        }
        buffer.writeln();
      }
    }
    
    buffer.writeln('[END KNOWLEDGE]');
    return buffer.toString();
  }

  /// Get relevant vector memories for a query (Infinite Recall)
  Future<String> getVectorContext(String query) async {
    final matches = await _vectorService.searchCloud(query);
    if (matches.isEmpty) return '';

    final buffer = StringBuffer('[DEEP RECALL]\n');
    for (var match in matches) {
      buffer.writeln('- ${match.content} (Confidence: High)');
    }
    buffer.writeln('[END DEEP RECALL]');
    return buffer.toString();
  }
  
  String _categoryLabel(MemoryCategory category) {
    switch (category) {
      case MemoryCategory.people: return 'PEOPLE IN USER\'S LIFE';
      case MemoryCategory.preferences: return 'USER PREFERENCES';
      case MemoryCategory.dates: return 'IMPORTANT DATES';
      case MemoryCategory.life: return 'LIFE CONTEXT';
      case MemoryCategory.emotional: return 'EMOTIONAL PATTERNS';
      case MemoryCategory.goals: return 'GOALS & ASPIRATIONS';
      case MemoryCategory.misc: return 'OTHER FACTS';
    }
  }
  
  /// Delete a specific memory
  Future<void> deleteMemory(String id) async {
    final index = _memoryBox?.values.toList().indexWhere((m) => m.id == id);
    if (index != null && index >= 0) {
      await _memoryBox?.deleteAt(index);
    }
  }
  
  /// Clear all extracted memories
  Future<void> clearMemories() async {
    await _memoryBox?.clear();
  }
  
  /// Update an existing memory
  Future<bool> updateMemory({
    required String id,
    String? content,
    MemoryCategory? category,
    List<String>? tags,
    int? importance,
  }) async {
    if (_memoryBox == null) await initialize();
    
    final memories = _memoryBox!.values.toList();
    final index = memories.indexWhere((m) => m.id == id);
    
    if (index < 0) return false;
    
    final existing = memories[index];
    final updated = ExtractedMemory(
      id: existing.id,
      content: content ?? existing.content,
      category: category ?? existing.category,
      extractedAt: existing.extractedAt,
      sourceMessageId: existing.sourceMessageId,
      tags: tags ?? existing.tags,
      importance: importance ?? existing.importance,
    );
    
    await _memoryBox!.putAt(index, updated);
    print('✏️ Updated memory: ${updated.content}');
    return true;
  }
  
  /// Get detailed statistics per category for Knowledge Center
  Map<String, dynamic> getMemoriesStats() {
    final memories = getAllMemories();
    
    final categoryStats = <MemoryCategory, int>{};
    for (var category in MemoryCategory.values) {
      categoryStats[category] = memories.where((m) => m.category == category).length;
    }
    
    // Calculate average importance
    double avgImportance = 0;
    if (memories.isNotEmpty) {
      avgImportance = memories.map((m) => m.importance).reduce((a, b) => a + b) / memories.length;
    }
    
    // Find most recent extraction
    DateTime? lastExtracted;
    if (memories.isNotEmpty) {
      lastExtracted = memories.map((m) => m.extractedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    }
    
    return {
      'total': memories.length,
      'categoryStats': categoryStats,
      'averageImportance': avgImportance,
      'lastExtracted': lastExtracted,
      'totalTags': memories.expand((m) => m.tags).toSet().length,
    };
  }
  
  /// Export ALL data to JSON for backup (GDPR/Trust)
  Future<String> exportFullDataDump() async {
    if (_chatBox == null || _memoryBox == null || _healthBox == null) await initialize();

    final memories = getAllMemories();
    final chat = getAllChatMessages();
    final health = getAllHealthEntries();

    final export = {
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
      'stats': getStats(),
      'data': {
        'memories': memories.map((m) => m.toJson()).toList(),
        'chatHistory': chat.map((c) => c.toJson()).toList(),
        'healthData': health.map((h) => h.toJson()).toList(),
      }
    };
    return const JsonEncoder.withIndent('  ').convert(export);
  }
  
  /// Delete all memories in a specific category
  Future<int> bulkDeleteByCategory(MemoryCategory category) async {
    if (_memoryBox == null) await initialize();
    
    final toDelete = <int>[];
    final memories = _memoryBox!.values.toList();
    
    for (var i = 0; i < memories.length; i++) {
      if (memories[i].category == category) {
        toDelete.add(i);
      }
    }
    
    // Delete in reverse order to maintain indices
    for (var i = toDelete.length - 1; i >= 0; i--) {
      await _memoryBox!.deleteAt(toDelete[i]);
    }
    
    print('🗑️ Deleted ${toDelete.length} memories from ${category.name}');
    return toDelete.length;
  }
  
  /// Get human-readable category label (public version for UI)
  String getCategoryLabel(MemoryCategory category) {
    return _categoryLabel(category);
  }
  
  /// Get category icon name for UI
  String getCategoryIcon(MemoryCategory category) {
    switch (category) {
      case MemoryCategory.people: return 'users';
      case MemoryCategory.preferences: return 'heart';
      case MemoryCategory.dates: return 'calendar';
      case MemoryCategory.life: return 'home';
      case MemoryCategory.emotional: return 'smile';
      case MemoryCategory.goals: return 'target';
      case MemoryCategory.misc: return 'folder';
    }
  }
  
  // ============= HEALTH DATA (ENCRYPTED) =============
  
  /// Add a health entry
  Future<void> addHealthEntry({
    required HealthEntryType type,
    required String content,
    int? moodScore,
    List<String> tags = const [],
    bool isConfidential = true,
  }) async {
    if (_healthBox == null) await initialize();
    
    final entry = HealthEntry.create(
      type: type,
      content: content,
      moodScore: moodScore,
      tags: tags,
      isConfidential: isConfidential,
    );
    
    await _healthBox!.add(entry);
    print('🔐 Stored encrypted health entry');
  }
  
  /// Get all health entries
  List<HealthEntry> getAllHealthEntries() {
    return _healthBox?.values.toList() ?? [];
  }
  
  /// Get health entries by type
  List<HealthEntry> getHealthEntriesByType(HealthEntryType type) {
    return getAllHealthEntries().where((e) => e.type == type).toList();
  }
  
  /// Delete a health entry
  Future<void> deleteHealthEntry(String id) async {
    final index = _healthBox?.values.toList().indexWhere((e) => e.id == id);
    if (index != null && index >= 0) {
      await _healthBox?.deleteAt(index);
    }
  }
  
  /// Clear all health data
  Future<void> clearHealthData() async {
    await _healthBox?.clear();
  }
  
  // ============= GLOBAL OPERATIONS =============
  
  /// Get full context for AI (combines chat + memories)
  String getFullAIContext({int chatMessageCount = 100}) {
    final chat = getChatContext(messageCount: chatMessageCount);
    final memories = getMemoryContext();
    
    return '$memories\n$chat';
  }
  
  /// Clear all data (for reset)
  Future<void> clearAllData() async {
    await clearChatHistory();
    await clearMemories();
    await clearHealthData();
    print('🗑️ All memory data cleared');
  }
  
  /// Delete all data created within the last [duration]
  Future<int> deleteDataFromTimeRange(Duration duration) async {
    if (_chatBox == null || _memoryBox == null || _healthBox == null) await initialize();
    
    final cutoff = DateTime.now().subtract(duration);
    int deletedCount = 0;
    
    // 1. Delete Chat Messages
    final chatKeysToDelete = <dynamic>[];
    for (var i = 0; i < _chatBox!.length; i++) {
        final msg = _chatBox!.getAt(i);
        if (msg != null && msg.timestamp.isAfter(cutoff)) {
            chatKeysToDelete.add(_chatBox!.keyAt(i));
        }
    }
    for (var key in chatKeysToDelete) {
        await _chatBox!.delete(key);
    }
    deletedCount += chatKeysToDelete.length;
    
    // 2. Delete Extracted Memories
    final memoryKeysToDelete = <dynamic>[];
    for (var i = 0; i < _memoryBox!.length; i++) {
        final mem = _memoryBox!.getAt(i);
        if (mem != null && mem.extractedAt.isAfter(cutoff)) {
            memoryKeysToDelete.add(_memoryBox!.keyAt(i));
        }
    }
    for (var key in memoryKeysToDelete) {
        await _memoryBox!.delete(key);
    }
    deletedCount += memoryKeysToDelete.length;
    
    // 3. Delete Health Entries
    final healthKeysToDelete = <dynamic>[];
    for (var i = 0; i < _healthBox!.length; i++) {
        final entry = _healthBox!.getAt(i);
        if (entry != null && entry.timestamp.isAfter(cutoff)) {
            healthKeysToDelete.add(_healthBox!.keyAt(i));
        }
    }
    for (var key in healthKeysToDelete) {
        await _healthBox!.delete(key);
    }
    deletedCount += healthKeysToDelete.length;
    
    print('🧹 Memory Audit: Deleted $deletedCount items created after $cutoff');
    return deletedCount;
  }

  /// Get stats
  Map<String, int> getStats() {
    return {
      'chatMessages': _chatBox?.length ?? 0,
      'extractedMemories': _memoryBox?.length ?? 0,
      'healthEntries': _healthBox?.length ?? 0,
    };
  }
}
