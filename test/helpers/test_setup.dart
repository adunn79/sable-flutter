import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Central test setup for initializing Hive, dotenv, and mocking platform channels
/// Call [setUpTestEnvironment] in setUpAll() for tests that need these services

bool _isInitialized = false;

/// Initialize the test environment with Hive, dotenv, and platform mocks
/// This should be called once in setUpAll() for test files that need these services
Future<void> setUpTestEnvironment() async {
  if (_isInitialized) return;
  
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Disable Google Fonts network fetching in tests (prevents network errors)
  GoogleFonts.config.allowRuntimeFetching = false;
  
  // Set up path provider mock for Hive
  PathProviderPlatform.instance = FakePathProviderPlatform();
  
  // Initialize Hive in test mode with temp directory
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
  
  // Open common boxes used by the app
  await _openTestBoxes();
  
  // Load dotenv with test fallbacks
  await _loadDotenv();
  
  // Mock common platform channels
  _mockPlatformChannels();
  
  _isInitialized = true;
}

/// Open Hive boxes commonly used by the app
Future<void> _openTestBoxes() async {
  try {
    // Core app boxes
    await Hive.openBox('journal_entries');
    await Hive.openBox('goals');
    await Hive.openBox('extracted_memories');
    await Hive.openBox('chat_messages');
    await Hive.openBox<Map<dynamic, dynamic>>('memory_spine');
    await Hive.openBox('user_preferences');
    await Hive.openBox('onboarding_state');
    await Hive.openBox('engagement_data');
    
    // Additional boxes for full coverage
    await Hive.openBox('journal_buckets');
    await Hive.openBox('journal_calendar');
    await Hive.openBox('gratitude_entries');
    await Hive.openBox('voice_notes');
    await Hive.openBox('insights_cache');
    await Hive.openBox('knowledge_center');
    await Hive.openBox('private_space');
    await Hive.openBox('alarm_data');
    await Hive.openBox('settings');
    await Hive.openBox('avatar_cache');
    await Hive.openBox('vault_data');
  } catch (e) {
    // Boxes may already be open, continue
    print('⚠️ Hive: Some boxes already open or failed: $e');
  }
}

/// Load dotenv with test fallbacks
Future<void> _loadDotenv() async {
  try {
    // Try loading .env file from project root
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // If .env doesn't exist, just continue - the app will use fallbacks
    // This is fine for tests that don't need real API keys
    print('⚠️ dotenv: .env file not found, tests will use mock responses');
  }
}

/// Mock common platform channels to prevent MissingPluginException
void _mockPlatformChannels() {
  // Now Playing channel
  const nowPlayingChannel = MethodChannel('com.sable.nowplaying');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(nowPlayingChannel, (call) async {
    switch (call.method) {
      case 'getNowPlaying':
        return null; // No music playing
      case 'play':
      case 'pause':
      case 'togglePlayPause':
      case 'next':
      case 'previous':
        return true;
      default:
        return null;
    }
  });
  
  // Reminders channel
  const remindersChannel = MethodChannel('com.sable.reminders');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(remindersChannel, (call) async {
    switch (call.method) {
      case 'hasPermission':
        return false;
      case 'requestPermission':
        return false;
      case 'getReminders':
        return <Map<String, dynamic>>[];
      default:
        return null;
    }
  });
  
  // CloudKit channel
  const cloudKitChannel = MethodChannel('com.sable.cloudkit');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(cloudKitChannel, (call) async {
    switch (call.method) {
      case 'isAvailable':
        return false;
      case 'checkAccountStatus':
        return 3; // noAccount
      default:
        return null;
    }
  });
  
  // Apple Intelligence channel
  const intelligenceChannel = MethodChannel('com.aureal.sable/apple_intelligence');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(intelligenceChannel, (call) async {
    switch (call.method) {
      case 'isAvailable':
        return false;
      default:
        return null;
    }
  });
}

/// Clean up test environment
Future<void> tearDownTestEnvironment() async {
  await Hive.close();
  _isInitialized = false;
}

/// Fake PathProvider for Hive in tests
class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return Directory.systemTemp.createTempSync('app_support_').path;
  }

  @override
  Future<String?> getLibraryPath() async {
    return Directory.systemTemp.createTempSync('library_').path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('documents_').path;
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return null;
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return null;
  }

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async {
    return null;
  }

  @override
  Future<String?> getDownloadsPath() async {
    return Directory.systemTemp.createTempSync('downloads_').path;
  }
}
