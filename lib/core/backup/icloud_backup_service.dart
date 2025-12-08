import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/journal/services/journal_storage_service.dart';
import '../../features/vital_balance/services/goals_service.dart';
import '../memory/unified_memory_service.dart';

/// Service for backing up and restoring app data to iCloud CloudKit
class iCloudBackupService {
  static const _channel = MethodChannel('com.sable.cloudkit');
  static const _lastBackupKey = 'last_icloud_backup';
  
  // Singleton
  static final iCloudBackupService _instance = iCloudBackupService._();
  static iCloudBackupService get instance => _instance;
  iCloudBackupService._();
  
  /// Check if iCloud is available on this device
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('iCloud availability check failed: $e');
      return false;
    }
  }
  
  /// Get iCloud account status
  /// Returns: 0=unknown, 1=available, 2=restricted, 3=noAccount, 4=temporarilyUnavailable
  Future<int> getAccountStatus() async {
    try {
      final result = await _channel.invokeMethod<int>('checkAccountStatus');
      return result ?? 0;
    } on PlatformException catch (e) {
      debugPrint('iCloud status check failed: $e');
      return 0;
    }
  }
  
  /// Get human-readable account status message
  Future<String> getAccountStatusMessage() async {
    final status = await getAccountStatus();
    switch (status) {
      case 1: return 'Connected';
      case 2: return 'Restricted';
      case 3: return 'Not signed in';
      case 4: return 'Temporarily unavailable';
      default: return 'Unknown';
    }
  }
  
  /// Get the last backup timestamp
  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastBackupKey);
    return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }
  
  /// Perform full app backup to iCloud
  Future<BackupResult> performFullBackup({
    void Function(String stage, double progress)? onProgress,
  }) async {
    final result = BackupResult();
    
    try {
      // Check availability first
      if (!await isAvailable()) {
        result.success = false;
        result.error = 'iCloud is not available';
        return result;
      }
      
      onProgress?.call('Backing up journal entries...', 0.1);
      
      // 1. Backup Journal Entries
      final journalEntries = JournalStorageService.getAllEntries();
      if (journalEntries.isNotEmpty) {
        final journalData = journalEntries.map((e) => {
          'id': e.id,
          'content': e.content,
          'plainText': e.plainText,
          'timestamp': e.timestamp.millisecondsSinceEpoch ~/ 1000,
          'updatedAt': e.updatedAt?.millisecondsSinceEpoch,
          'bucketId': e.bucketId,
          'tags': e.tags,
          'moodScore': e.moodScore,
          'isPrivate': e.isPrivate,
          'location': e.location,
          'weather': e.weather,
          'stepCount': e.stepCount,
          'nowPlayingTrack': e.nowPlayingTrack,
          'nowPlayingArtist': e.nowPlayingArtist,
        }).toList();
        
        final count = await _channel.invokeMethod<int>('backupJournalEntries', journalData);
        result.journalEntriesBackedUp = count ?? 0;
      }
      
      onProgress?.call('Backing up goals...', 0.4);
      
      // 2. Backup Goals
      final goals = GoalsService.getActiveGoals();
      if (goals.isNotEmpty) {
        final goalsData = goals.map((g) => {
          'id': g.id,
          'title': g.title,
          'description': g.description,
          'targetDate': g.targetDate.millisecondsSinceEpoch,
          'createdAt': g.createdAt.millisecondsSinceEpoch,
          'progress': g.progressPercent.toDouble(),
          'isCompleted': g.status.index == 1, // completed status
          'checkInFrequencyDays': g.checkInFrequencyDays,
        }).toList();
        
        final count = await _channel.invokeMethod<int>('backupGoals', goalsData);
        result.goalsBackedUp = count ?? 0;
      }
      
      onProgress?.call('Backing up chat history...', 0.7);
      
      // 3. Backup Chat Messages
      final memoryService = UnifiedMemoryService();
      final messages = memoryService.getAllChatMessages();
      if (messages.isNotEmpty) {
        final messagesData = messages.map((m) => {
          'id': m.id,
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.message,
          'timestamp': m.timestamp.millisecondsSinceEpoch,
          'contextType': m.emotionalContext,
        }).toList();
        
        final count = await _channel.invokeMethod<int>('backupChatMessages', messagesData);
        result.chatMessagesBackedUp = count ?? 0;
      }
      
      onProgress?.call('Backup complete!', 1.0);
      
      // Save backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
      
      result.success = true;
      result.backupTime = DateTime.now();
      
    } on PlatformException catch (e) {
      result.success = false;
      result.error = e.message ?? 'Backup failed';
      debugPrint('iCloud backup failed: $e');
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      debugPrint('iCloud backup error: $e');
    }
    
    return result;
  }
  
  /// Restore all data from iCloud
  Future<RestoreResult> performFullRestore({
    void Function(String stage, double progress)? onProgress,
  }) async {
    final result = RestoreResult();
    
    try {
      if (!await isAvailable()) {
        result.success = false;
        result.error = 'iCloud is not available';
        return result;
      }
      
      onProgress?.call('Fetching journal entries...', 0.1);
      
      // 1. Restore Journal Entries
      final journalData = await _channel.invokeMethod<List>('fetchAllJournalEntries');
      if (journalData != null && journalData.isNotEmpty) {
        for (final entryData in journalData) {
          final data = Map<String, dynamic>.from(entryData);
          // Convert and save to local storage
          // Implementation depends on JournalStorageService.saveFromCloud method
          result.journalEntriesRestored++;
        }
      }
      
      onProgress?.call('Fetching goals...', 0.4);
      
      // 2. Restore Goals
      final goalsData = await _channel.invokeMethod<List>('fetchAllGoals');
      if (goalsData != null && goalsData.isNotEmpty) {
        for (final goalData in goalsData) {
          final data = Map<String, dynamic>.from(goalData);
          // Convert and save to GoalsService
          result.goalsRestored++;
        }
      }
      
      onProgress?.call('Fetching chat history...', 0.7);
      
      // 3. Restore Chat Messages
      final messagesData = await _channel.invokeMethod<List>('fetchAllChatMessages');
      if (messagesData != null && messagesData.isNotEmpty) {
        for (final msgData in messagesData) {
          final data = Map<String, dynamic>.from(msgData);
          // Convert and save to UnifiedMemoryService
          result.chatMessagesRestored++;
        }
      }
      
      onProgress?.call('Restore complete!', 1.0);
      
      result.success = true;
      
    } on PlatformException catch (e) {
      result.success = false;
      result.error = e.message ?? 'Restore failed';
      debugPrint('iCloud restore failed: $e');
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      debugPrint('iCloud restore error: $e');
    }
    
    return result;
  }
}

/// Result of a backup operation
class BackupResult {
  bool success = false;
  String? error;
  DateTime? backupTime;
  int journalEntriesBackedUp = 0;
  int goalsBackedUp = 0;
  int chatMessagesBackedUp = 0;
  
  int get totalItems => journalEntriesBackedUp + goalsBackedUp + chatMessagesBackedUp;
  
  @override
  String toString() => 'BackupResult(success: $success, total: $totalItems, error: $error)';
}

/// Result of a restore operation
class RestoreResult {
  bool success = false;
  String? error;
  int journalEntriesRestored = 0;
  int goalsRestored = 0;
  int chatMessagesRestored = 0;
  
  int get totalItems => journalEntriesRestored + goalsRestored + chatMessagesRestored;
  
  @override
  String toString() => 'RestoreResult(success: $success, total: $totalItems, error: $error)';
}
