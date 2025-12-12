/// User Data Service for Aeliana
/// Handles account deletion and data export (GDPR/CCPA compliance)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

class UserDataService {
  static UserDataService? _instance;
  static UserDataService get instance => _instance ??= UserDataService._();
  
  UserDataService._();
  
  /// Export all user data as a JSON file
  /// Returns the path to the exported file
  Future<String?> exportUserData() async {
    try {
      debugPrint('📦 Starting user data export...');
      
      final exportData = <String, dynamic>{
        'export_date': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
        'data': {},
      };
      
      // 1. Export SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        // Skip sensitive keys
        if (key.contains('password') || key.contains('pin') || key.contains('api_key')) {
          continue;
        }
        final value = prefs.get(key);
        if (value != null) {
          prefsData[key] = value;
        }
      }
      exportData['data']['preferences'] = prefsData;
      debugPrint('📦 Exported ${prefsData.length} preferences');
      
      // 2. Export Hive boxes (chat messages, memories, health)
      try {
        if (Hive.isBoxOpen('chat_messages')) {
          final chatBox = Hive.box('chat_messages');
          final chatMessages = <Map<String, dynamic>>[];
          for (int i = 0; i < chatBox.length; i++) {
            final msg = chatBox.getAt(i);
            if (msg is Map) {
              chatMessages.add(Map<String, dynamic>.from(msg));
            }
          }
          exportData['data']['chat_messages'] = chatMessages;
          debugPrint('📦 Exported ${chatMessages.length} chat messages');
        }
        
        if (Hive.isBoxOpen('extracted_memories')) {
          final memoriesBox = Hive.box('extracted_memories');
          final memories = <Map<String, dynamic>>[];
          for (int i = 0; i < memoriesBox.length; i++) {
            final mem = memoriesBox.getAt(i);
            if (mem is Map) {
              memories.add(Map<String, dynamic>.from(mem));
            }
          }
          exportData['data']['memories'] = memories;
          debugPrint('📦 Exported ${memories.length} memories');
        }
        
        if (Hive.isBoxOpen('journal_entries')) {
          final journalBox = Hive.box('journal_entries');
          final entries = <Map<String, dynamic>>[];
          for (int i = 0; i < journalBox.length; i++) {
            final entry = journalBox.getAt(i);
            if (entry is Map) {
              entries.add(Map<String, dynamic>.from(entry));
            }
          }
          exportData['data']['journal_entries'] = entries;
          debugPrint('📦 Exported ${entries.length} journal entries');
        }
      } catch (e) {
        debugPrint('⚠️ Hive export error: $e');
      }
      
      // 3. Get user profile data
      exportData['data']['user_profile'] = {
        'name': prefs.getString('userName'),
        'birthday': prefs.getString('userBirthday'),
        'created_at': prefs.getString('onboarding_completed_date'),
      };
      
      // 4. Write to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/aeliana_export_$timestamp.json';
      final file = File(filePath);
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      await file.writeAsString(jsonString);
      
      debugPrint('✅ User data exported to: $filePath');
      return filePath;
      
    } catch (e) {
      debugPrint('❌ Export failed: $e');
      return null;
    }
  }
  
  /// Share the exported data file
  Future<void> shareExportedData() async {
    final filePath = await exportUserData();
    if (filePath != null) {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Aeliana Data Export',
        text: 'Your personal data from Aeliana',
      );
    }
  }
  
  /// Delete all user data (account deletion)
  /// Returns true if successful
  Future<bool> deleteAllUserData({bool confirmDeletion = false}) async {
    if (!confirmDeletion) {
      debugPrint('⚠️ Deletion requires explicit confirmation');
      return false;
    }
    
    try {
      debugPrint('🗑️ Starting account deletion...');
      
      // 1. Clear all SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('🗑️ Cleared SharedPreferences');
      
      // 2. Clear all Hive boxes
      try {
        final boxNames = [
          'chat_messages',
          'extracted_memories',
          'health_entries',
          'journal_entries',
          'journal_buckets',
          'private_space_messages',
          'private_user_persona',
        ];
        
        for (final boxName in boxNames) {
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.clear();
            debugPrint('🗑️ Cleared Hive box: $boxName');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Hive clear error: $e');
      }
      
      // 3. Delete exported files
      try {
        final directory = await getApplicationDocumentsDirectory();
        final files = directory.listSync();
        for (final file in files) {
          if (file.path.contains('aeliana_export')) {
            await file.delete();
            debugPrint('🗑️ Deleted export file: ${file.path}');
          }
        }
      } catch (e) {
        debugPrint('⚠️ File cleanup error: $e');
      }
      
      // 4. Mark as deleted for cloud sync
      final newPrefs = await SharedPreferences.getInstance();
      await newPrefs.setBool('account_deleted', true);
      await newPrefs.setString('deletion_date', DateTime.now().toIso8601String());
      
      debugPrint('✅ Account deletion complete');
      return true;
      
    } catch (e) {
      debugPrint('❌ Account deletion failed: $e');
      return false;
    }
  }
  
  /// Get data statistics for display
  Future<Map<String, int>> getDataStatistics() async {
    final stats = <String, int>{};
    
    try {
      // Chat messages
      if (Hive.isBoxOpen('chat_messages')) {
        stats['chat_messages'] = Hive.box('chat_messages').length;
      }
      
      // Memories
      if (Hive.isBoxOpen('extracted_memories')) {
        stats['memories'] = Hive.box('extracted_memories').length;
      }
      
      // Journal entries
      if (Hive.isBoxOpen('journal_entries')) {
        stats['journal_entries'] = Hive.box('journal_entries').length;
      }
      
      // Private Space messages
      if (Hive.isBoxOpen('private_space_messages')) {
        stats['private_messages'] = Hive.box('private_space_messages').length;
      }
      
      // Preferences count
      final prefs = await SharedPreferences.getInstance();
      stats['preferences'] = prefs.getKeys().length;
      
    } catch (e) {
      debugPrint('⚠️ Stats error: $e');
    }
    
    return stats;
  }
}
