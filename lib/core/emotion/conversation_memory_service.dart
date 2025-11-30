import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent conversation history storage
/// Stores all messages with timestamps for long-term memory
class ConversationMemoryService {
  static const String _keyMessages = 'conversation_messages';
  static const int _maxStoredMessages = 100; // Store up to 100 messages

  final SharedPreferences _prefs;

  ConversationMemoryService(this._prefs);

  static Future<ConversationMemoryService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ConversationMemoryService(prefs);
  }

  /// Get all stored messages
  List<ConversationMessage> getAllMessages() {
    final jsonStr = _prefs.getString(_keyMessages);
    if (jsonStr == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map((json) => ConversationMessage.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a new message to history
  Future<void> addMessage({
    required String message,
    required bool isUser,
  }) async {
    final messages = getAllMessages();
    
    messages.add(ConversationMessage(
      message: message,
      isUser: isUser,
      timestamp: DateTime.now(),
    ));

    // Keep only last N messages to avoid storage bloat
    if (messages.length > _maxStoredMessages) {
      messages.removeRange(0, messages.length - _maxStoredMessages);
    }

    await _saveMessages(messages);
  }

  /// Get recent messages (last N)
  List<ConversationMessage> getRecentMessages(int count) {
    final messages = getAllMessages();
    if (messages.length <= count) return messages;
    return messages.sublist(messages.length - count);
  }

  /// Get messages from today
  List<ConversationMessage> getTodayMessages() {
    final messages = getAllMessages();
    final now = DateTime.now();
    
    return messages.where((msg) {
      return msg.timestamp.year == now.year &&
          msg.timestamp.month == now.month &&
          msg.timestamp.day == now.day;
    }).toList();
  }

  /// Get conversation context string (last N messages)
  String getConversationContext({int messageCount = 20}) {
    final recentMessages = getRecentMessages(messageCount);
    if (recentMessages.isEmpty) return '';

    final buffer = StringBuffer('[RECENT CONVERSATION]\n');
    for (var msg in recentMessages) {
      final speaker = msg.isUser ? 'User' : 'You';
      buffer.writeln('$speaker: ${msg.message}');
    }
    buffer.writeln('[END CONVERSATION]');
    
    return buffer.toString();
  }

  /// Clear all conversation history
  Future<void> clearHistory() async {
    await _prefs.remove(_keyMessages);
  }

  Future<void> _saveMessages(List<ConversationMessage> messages) async {
    final jsonList = messages.map((msg) => msg.toJson()).toList();
    await _prefs.setString(_keyMessages, jsonEncode(jsonList));
  }

  /// Get total message count
  int get messageCount => getAllMessages().length;
}

/// A single conversation message with metadata
class ConversationMessage {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  ConversationMessage({
    required this.message,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'isUser': isUser,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      message: json['message'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}
