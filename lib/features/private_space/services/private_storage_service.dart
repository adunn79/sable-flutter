import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/private_message.dart';

/// Completely isolated storage service for Private Space
/// NEVER accessed by any other part of the app
class PrivateStorageService {
  static PrivateStorageService? _instance;
  static const String _boxName = 'private_space_messages';
  static const String _encryptionKeyName = 'private_space_encryption_key';
  static const String _photosBoxName = 'private_space_photos';
  static const String _factsBoxName = 'private_space_facts';
  
  Box<PrivateMessage>? _messagesBox;
  Box<String>? _photosBox; // Stores base64 encoded photos
  Box<String>? _factsBox; // Stores private facts (e.g. preferences, pronouns)
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  PrivateStorageService._();
  
  static Future<PrivateStorageService> getInstance() async {
    if (_instance == null) {
      _instance = PrivateStorageService._();
      await _instance!._initialize();
    }
    return _instance!;
  }
  
  Future<void> _initialize() async {
    try {
      // Get or create encryption key
      String? encryptionKeyString = await _secureStorage.read(key: _encryptionKeyName);
      
      if (encryptionKeyString == null) {
        // Generate new key
        final key = Hive.generateSecureKey();
        encryptionKeyString = base64Encode(key);
        await _secureStorage.write(key: _encryptionKeyName, value: encryptionKeyString);
      }
      
      final encryptionKey = base64Decode(encryptionKeyString);
      
      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(50)) {
        Hive.registerAdapter(PrivateMessageAdapter());
      }
      
      // Open encrypted boxes
      _messagesBox = await Hive.openBox<PrivateMessage>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      
      _photosBox = await Hive.openBox<String>(
        _photosBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );

      _factsBox = await Hive.openBox<String>(
        _factsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      
      debugPrint('🔒 Private Space storage initialized (encrypted)');
    } catch (e) {
      debugPrint('❌ Error initializing Private Space storage: $e');
    }
  }
  
  // Messages
  Future<void> saveMessage(PrivateMessage message) async {
    await _messagesBox?.put(message.id, message);
  }
  
  List<PrivateMessage> getAllMessages() {
    return _messagesBox?.values.toList() ?? [];
  }
  
  List<PrivateMessage> getRecentMessages({int limit = 50}) {
    final messages = getAllMessages();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (messages.length > limit) {
      return messages.sublist(messages.length - limit);
    }
    return messages;
  }
  
  Future<void> deleteMessage(String id) async {
    await _messagesBox?.delete(id);
  }
  
  Future<void> clearAllMessages() async {
    await _messagesBox?.clear();
  }
  
  // Photos (stored as base64 in encrypted box)
  Future<void> savePhoto(String id, String base64Data) async {
    await _photosBox?.put(id, base64Data);
  }
  
  String? getPhoto(String id) {
    return _photosBox?.get(id);
  }
  
  List<String> getAllPhotoIds() {
    return _photosBox?.keys.cast<String>().toList() ?? [];
  }
  
  Future<void> deletePhoto(String id) async {
    await _photosBox?.delete(id);
  }
  
  Future<void> clearAllPhotos() async {
    await _photosBox?.clear();
  }

  // Facts (Simple strings for preferences/context)
  Future<void> saveFact(String fact) async {
    if (_factsBox == null) return;
    // Simple dedup
    if (!_factsBox!.values.contains(fact)) {
      await _factsBox!.add(fact);
    }
  }

  List<String> getFacts() {
    return _factsBox?.values.toList() ?? [];
  }

  Future<void> removeFact(String fact) async {
    if (_factsBox == null) return;
    final map = _factsBox!.toMap();
    for (final key in map.keys) {
      if (map[key] == fact) {
        await _factsBox!.delete(key);
        break; // Only delete one instance
      }
    }
  }

  Future<void> clearAllFacts() async {
    await _factsBox?.clear();
  }
  
  // Nuclear option - delete everything
  Future<void> deleteAllPrivateData() async {
    await clearAllMessages();
    await clearAllPhotos();
    await clearAllFacts();
    
    // Also clear private space preferences
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('private_space_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
    
    // Delete encryption key (makes old data unrecoverable)
    await _secureStorage.delete(key: _encryptionKeyName);
    
    debugPrint('🗑️ All Private Space data deleted');
  }
  
  // Stats
  int get messageCount => _messagesBox?.length ?? 0;
  int get photoCount => _photosBox?.length ?? 0;
}
