import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sable/core/memory/models/chat_message.dart';
import 'package:sable/core/memory/models/extracted_memory.dart';
import 'package:sable/core/memory/models/health_entry.dart';

/// Unified Memory Service
/// Manages all Hive boxes for persistent, searchable AI memory
class UnifiedMemoryService {
  static const String _chatBoxName = 'chat_history';
  static const String _memoryBoxName = 'extracted_memories';
  static const String _healthBoxName = 'health_data';
  static const String _encryptionKeyName = 'hive_encryption_key';
  
  static const int _maxChatMessages = 500; // Increased from 100
  
  static final UnifiedMemoryService _instance = UnifiedMemoryService._internal();
  factory UnifiedMemoryService() => _instance;
  UnifiedMemoryService._internal();
  
  Box<ChatMessage>? _chatBox;
  Box<ExtractedMemory>? _memoryBox;
  Box<HealthEntry>? _healthBox;
  
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
    _chatBox = await Hive.openBox<ChatMessage>(_chatBoxName);
    _memoryBox = await Hive.openBox<ExtractedMemory>(_memoryBoxName);
    
    // Open encrypted box for health data
    final encryptionKey = await _getOrCreateEncryptionKey();
    _healthBox = await Hive.openBox<HealthEntry>(
      _healthBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    
    _initialized = true;
    print('✅ UnifiedMemoryService initialized');
    print('📂 Chat messages: ${_chatBox?.length ?? 0}');
    print('🧠 Extracted memories: ${_memoryBox?.length ?? 0}');
    print('🔐 Health entries: ${_healthBox?.length ?? 0}');
  }
  
  /// Get or create encryption key for health data
  Future<Uint8List> _getOrCreateEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();
    
    String? keyString = await secureStorage.read(key: _encryptionKeyName);
    
    if (keyString == null) {
      // Generate new key
      final key = Hive.generateSecureKey();
      keyString = base64Encode(key);
      await secureStorage.write(key: _encryptionKeyName, value: keyString);
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
  String getChatContext({int messageCount = 30}) {
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
  
  /// Add an extracted memory
  Future<void> addMemory({
    required String content,
    required MemoryCategory category,
    String? sourceMessageId,
    List<String> tags = const [],
    int importance = 3,
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
    );
    
    await _memoryBox!.add(memory);
    print('🧠 Stored memory: $content');
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
  String getFullAIContext({int chatMessageCount = 30}) {
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
  
  /// Get stats
  Map<String, int> getStats() {
    return {
      'chatMessages': _chatBox?.length ?? 0,
      'extractedMemories': _memoryBox?.length ?? 0,
      'healthEntries': _healthBox?.length ?? 0,
    };
  }
}
