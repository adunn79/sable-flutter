import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum MemoryCategory {
  family,
  favorites,
  friends,
  pets,
  memories,
  misc,
}

class MemoryItem {
  final String id;
  final String content;
  final MemoryCategory category;
  final DateTime timestamp;
  final List<String> tags;

  MemoryItem({
    required this.id,
    required this.content,
    required this.category,
    required this.timestamp,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'category': category.name,
    'timestamp': timestamp.toIso8601String(),
    'tags': tags,
  };

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'],
      content: json['content'],
      category: MemoryCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => MemoryCategory.misc,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

class StructuredMemoryService {
  static const String _fileName = 'structured_memory.json';
  List<MemoryItem> _memories = [];

  // Singleton pattern
  static final StructuredMemoryService _instance = StructuredMemoryService._internal();
  factory StructuredMemoryService() => _instance;
  StructuredMemoryService._internal();

  Future<void> initialize() async {
    await _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _memories = jsonList.map((j) => MemoryItem.fromJson(j)).toList();
      }
    } catch (e) {
      print('Error loading structured memory: $e');
    }
  }

  Future<void> _saveMemories() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      final jsonList = _memories.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving structured memory: $e');
    }
  }

  Future<void> addMemory({
    required String content,
    required MemoryCategory category,
    List<String> tags = const [],
  }) async {
    final newItem = MemoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      category: category,
      timestamp: DateTime.now(),
      tags: tags,
    );
    
    _memories.add(newItem);
    await _saveMemories();
  }

  List<MemoryItem> getMemoriesByCategory(MemoryCategory category) {
    return _memories.where((m) => m.category == category).toList();
  }
  
  List<MemoryItem> getAllMemories() {
    return List.unmodifiable(_memories);
  }

  Future<void> deleteMemory(String id) async {
    _memories.removeWhere((m) => m.id == id);
    await _saveMemories();
  }
  
  /// Get formatted context string for AI
  String getMemoryContext() {
    if (_memories.isEmpty) return '';
    
    final buffer = StringBuffer('[PERSISTENT MEMORY]\n');
    
    for (var category in MemoryCategory.values) {
      final items = getMemoriesByCategory(category);
      if (items.isNotEmpty) {
        buffer.writeln('${category.name.toUpperCase()}:');
        for (var item in items) {
          buffer.writeln('- ${item.content}');
        }
        buffer.writeln();
      }
    }
    
    buffer.writeln('[END MEMORY]');
    return buffer.toString();
  }
}
