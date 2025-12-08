import 'dart:convert';
import 'dart:io' show Platform;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_entry.dart';
import '../models/journal_bucket.dart';

/// Service for managing journal storage using Hive (offline-first, encrypted)
class JournalStorageService {
  static const String _entriesBoxName = 'journal_entries_encrypted';
  static const String _bucketsBoxName = 'journal_buckets_encrypted';
  static const String _encryptionKeyName = 'journal_encryption_key';
  
  static bool _isInitialized = false;
  
  /// Get or create encryption key
  static Future<List<int>> _getOrCreateEncryptionKey() async {
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
  
  /// Initialize Hive and register adapters
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await Hive.initFlutter();
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(JournalEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(JournalBucketAdapter());
    }
    
    // Get encryption key
    final encryptionKey = await _getOrCreateEncryptionKey();
    
    // Open encrypted boxes with error handling
    try {
      await Hive.openBox<JournalEntry>(
        _entriesBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      await Hive.openBox<JournalBucket>(
        _bucketsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      print('\u26a0\ufe0f Journal data migration issue, resetting boxes: $e');
      await Hive.deleteBoxFromDisk(_entriesBoxName);
      await Hive.deleteBoxFromDisk(_bucketsBoxName);
      await Hive.openBox<JournalEntry>(
        _entriesBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      await Hive.openBox<JournalBucket>(
        _bucketsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    }
    
    _isInitialized = true;
    print('\u2705 Journal storage initialized (ENCRYPTED)');
  }
  
  /// Get entries box
  static Box<JournalEntry> get _entriesBox => 
      Hive.box<JournalEntry>(_entriesBoxName);
  
  /// Get buckets box
  static Box<JournalBucket> get _bucketsBox => 
      Hive.box<JournalBucket>(_bucketsBoxName);
  
  // ============ BUCKET OPERATIONS ============
  
  /// Get all journal buckets
  static List<JournalBucket> getAllBuckets() {
    final buckets = _bucketsBox.values.toList();
    buckets.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return buckets;
  }
  
  /// Get bucket by ID
  static JournalBucket? getBucket(String id) {
    return _bucketsBox.get(id);
  }
  
  /// Create or update a bucket
  static Future<void> saveBucket(JournalBucket bucket) async {
    await _bucketsBox.put(bucket.id, bucket);
  }
  
  /// Delete a bucket (entries must be deleted or moved first)
  static Future<void> deleteBucket(String id) async {
    await _bucketsBox.delete(id);
  }
  
  /// Create default buckets for new users
  static Future<void> createDefaultBuckets() async {
    if (_bucketsBox.isEmpty) {
      final defaults = JournalBucket.getDefaultBuckets();
      for (final bucket in defaults) {
        await saveBucket(bucket);
      }
    }
  }
  
  // ============ ENTRY OPERATIONS ============
  
  /// Create a new journal entry
  static Future<JournalEntry> createEntry({
    required String content,
    required String plainText,
    required String bucketId,
    List<String> tags = const [],
    int? moodScore,
    bool? isPrivate,
    String? location,
    double? latitude,
    double? longitude,
    String? weather,
    List<String> mediaUrls = const [],
  }) async {
    // Check if bucket is a vault (forces private)
    final bucket = getBucket(bucketId);
    final forcePrivate = bucket?.isVault ?? false;
    final defaultPrivacy = bucket?.avatarAccessDefault ?? true;
    
    final entry = JournalEntry(
      id: const Uuid().v4(),
      content: content,
      plainText: plainText,
      timestamp: DateTime.now(),
      bucketId: bucketId,
      tags: tags,
      moodScore: moodScore,
      isPrivate: forcePrivate ? true : (isPrivate ?? !defaultPrivacy),
      location: location,
      latitude: latitude,
      longitude: longitude,
      weather: weather,
      mediaUrls: mediaUrls,
      isSynced: false,
    );
    
    await _entriesBox.put(entry.id, entry);
    
    // Update bucket entry count
    if (bucket != null) {
      await saveBucket(bucket.copyWith(entryCount: bucket.entryCount + 1));
    }
    
    return entry;
  }
  
  /// Get all entries for a bucket
  static List<JournalEntry> getEntriesForBucket(String bucketId) {
    return _entriesBox.values
        .where((e) => e.bucketId == bucketId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// Get all entries (across all buckets)
  static List<JournalEntry> getAllEntries() {
    return _entriesBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// Get entries for a specific date
  static List<JournalEntry> getEntriesForDate(DateTime date) {
    return _entriesBox.values.where((e) =>
        e.timestamp.year == date.year &&
        e.timestamp.month == date.month &&
        e.timestamp.day == date.day
    ).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// Get entries for a date range
  static List<JournalEntry> getEntriesInRange(DateTime start, DateTime end) {
    return _entriesBox.values.where((e) =>
        e.timestamp.isAfter(start) && e.timestamp.isBefore(end)
    ).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// Get entry by ID
  static JournalEntry? getEntry(String id) {
    return _entriesBox.get(id);
  }
  
  /// Update an entry
  static Future<void> updateEntry(JournalEntry entry) async {
    final updated = entry.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await _entriesBox.put(entry.id, updated);
  }
  
  /// Delete an entry
  static Future<void> deleteEntry(String id) async {
    final entry = getEntry(id);
    if (entry != null) {
      // Update bucket count
      final bucket = getBucket(entry.bucketId);
      if (bucket != null && bucket.entryCount > 0) {
        await saveBucket(bucket.copyWith(entryCount: bucket.entryCount - 1));
      }
      await _entriesBox.delete(id);
    }
  }
  
  /// Search entries by text
  static List<JournalEntry> searchEntries(String query) {
    final lowerQuery = query.toLowerCase();
    return _entriesBox.values.where((e) =>
        e.plainText.toLowerCase().contains(lowerQuery) ||
        e.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))
    ).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// Get entries with specific tag
  static List<JournalEntry> getEntriesByTag(String tag) {
    return _entriesBox.values.where((e) =>
        e.tags.contains(tag)
    ).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// Get "On This Day" entries from previous years
  static List<JournalEntry> getOnThisDayEntries() {
    final today = DateTime.now();
    return _entriesBox.values.where((e) =>
        e.timestamp.month == today.month &&
        e.timestamp.day == today.day &&
        e.timestamp.year < today.year
    ).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Oldest first
  }
  
  /// Get unsynced entries for cloud sync
  static List<JournalEntry> getUnsyncedEntries() {
    return _entriesBox.values.where((e) => !e.isSynced).toList();
  }
  
  /// Mark entry as synced
  static Future<void> markAsSynced(String id, String firestoreId) async {
    final entry = getEntry(id);
    if (entry != null) {
      await _entriesBox.put(id, entry.copyWith(
        isSynced: true,
        firestoreId: firestoreId,
      ));
    }
  }
  
  /// Get average mood for a date (for calendar display)
  static int? getAverageMoodForDate(DateTime date) {
    final entries = getEntriesForDate(date);
    final moodEntries = entries.where((e) => e.moodScore != null);
    if (moodEntries.isEmpty) return null;
    
    final sum = moodEntries.fold<int>(0, (sum, e) => sum + e.moodScore!);
    return (sum / moodEntries.length).round();
  }
  
  /// Get all unique tags
  static List<String> getAllTags() {
    final tags = <String>{};
    for (final entry in _entriesBox.values) {
      tags.addAll(entry.tags);
    }
    return tags.toList()..sort();
  }
  
  /// Get streak count (consecutive days with entries)
  static int getCurrentStreak() {
    final today = DateTime.now();
    int streak = 0;
    DateTime checkDate = today;
    
    while (true) {
      final entries = getEntriesForDate(checkDate);
      if (entries.isEmpty) break;
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }
  
  /// Close all boxes (for cleanup)
  static Future<void> close() async {
    await Hive.close();
    _isInitialized = false;
  }
}
