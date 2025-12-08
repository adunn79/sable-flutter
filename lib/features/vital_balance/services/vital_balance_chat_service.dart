import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Chat message for Vital Balance goal coaching
/// Stored separately from main chat - encrypted and isolated
class VitalBalanceMessage {
  final String id;
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final String? goalId; // Optional: linked to specific goal

  VitalBalanceMessage({
    required this.id,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.goalId,
  });

  factory VitalBalanceMessage.create({
    required String message,
    required bool isUser,
    String? goalId,
  }) {
    return VitalBalanceMessage(
      id: const Uuid().v4(),
      message: message,
      isUser: isUser,
      timestamp: DateTime.now(),
      goalId: goalId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'isUser': isUser,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'goalId': goalId,
  };

  factory VitalBalanceMessage.fromJson(Map<String, dynamic> json) => VitalBalanceMessage(
    id: json['id'] as String,
    message: json['message'] as String,
    isUser: json['isUser'] as bool,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    goalId: json['goalId'] as String?,
  );
}

/// Service for Vital Balance chat history - separate from main chat
/// Encrypted and stored independently for goal coaching conversations
class VitalBalanceChatService {
  static const String _boxName = 'vital_balance_chat_encrypted';
  static const String _encryptionKeyName = 'vital_balance_chat_key';
  static const int _maxMessages = 500;
  
  static VitalBalanceChatService? _instance;
  Box<String>? _box; // Store as JSON strings
  
  VitalBalanceChatService._();
  
  static Future<VitalBalanceChatService> getInstance() async {
    if (_instance == null) {
      _instance = VitalBalanceChatService._();
      await _instance!._initialize();
    }
    return _instance!;
  }
  
  Future<List<int>> _getOrCreateEncryptionKey() async {
    String? keyString;
    final useFallback = Platform.isMacOS || Platform.isLinux;
    
    if (useFallback) {
      final prefs = await SharedPreferences.getInstance();
      keyString = prefs.getString(_encryptionKeyName);
      if (keyString == null) {
        final key = Hive.generateSecureKey();
        keyString = base64Encode(key);
        await prefs.setString(_encryptionKeyName, keyString);
      }
    } else {
      const secureStorage = FlutterSecureStorage();
      try {
        keyString = await secureStorage.read(key: _encryptionKeyName);
        if (keyString == null) {
          final key = Hive.generateSecureKey();
          keyString = base64Encode(key);
          await secureStorage.write(key: _encryptionKeyName, value: keyString);
        }
      } catch (e) {
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
  
  Future<void> _initialize() async {
    try {
      final encryptionKey = await _getOrCreateEncryptionKey();
      _box = await Hive.openBox<String>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      debugPrint('✅ VitalBalanceChatService initialized (${_box?.length ?? 0} messages, ENCRYPTED)');
    } catch (e) {
      debugPrint('❌ VitalBalanceChatService init error: $e');
    }
  }
  
  /// Add a message
  Future<void> addMessage({
    required String message,
    required bool isUser,
    String? goalId,
  }) async {
    final msg = VitalBalanceMessage.create(
      message: message,
      isUser: isUser,
      goalId: goalId,
    );
    
    await _box?.add(jsonEncode(msg.toJson()));
    
    // Trim to max messages
    if ((_box?.length ?? 0) > _maxMessages) {
      final excess = _box!.length - _maxMessages;
      for (var i = 0; i < excess; i++) {
        await _box!.deleteAt(0);
      }
    }
  }
  
  /// Get all messages
  List<VitalBalanceMessage> getAllMessages() {
    if (_box == null) return [];
    return _box!.values.map((json) {
      try {
        return VitalBalanceMessage.fromJson(jsonDecode(json));
      } catch (e) {
        return null;
      }
    }).whereType<VitalBalanceMessage>().toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
  
  /// Get recent messages for AI context
  List<VitalBalanceMessage> getRecentMessages({int limit = 100}) {
    final all = getAllMessages();
    if (all.length <= limit) return all;
    return all.sublist(all.length - limit);
  }
  
  /// Get messages for a specific goal
  List<VitalBalanceMessage> getMessagesForGoal(String goalId) {
    return getAllMessages().where((m) => m.goalId == goalId).toList();
  }
  
  /// Build context string for AI
  String getChatContext({int messageCount = 100}) {
    final messages = getRecentMessages(limit: messageCount);
    if (messages.isEmpty) return '';
    
    final buffer = StringBuffer('[VITAL BALANCE CONVERSATION]\n');
    for (var msg in messages) {
      final speaker = msg.isUser ? 'User' : 'Coach';
      buffer.writeln('$speaker: ${msg.message}');
    }
    buffer.writeln('[END CONVERSATION]');
    return buffer.toString();
  }
  
  /// Clear all messages
  Future<void> clearAll() async {
    await _box?.clear();
    debugPrint('🗑️ Vital Balance chat cleared');
  }
  
  /// Get stats
  int get messageCount => _box?.length ?? 0;
}
