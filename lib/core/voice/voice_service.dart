import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for voice input (STT) and output (TTS)
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  
  static const String _keySelectedVoice = 'selected_voice_id';
  static const String _keyAutoSpeak = 'auto_speak_enabled';
  
  /// Initialize the voice service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Initialize speech-to-text
      final speechAvailable = await _speech.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) => debugPrint('Speech status: $status'),
      );
      
      // Initialize text-to-speech
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5); // Natural speaking rate
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      // Load saved voice preference
      await _loadVoicePreference();
      
      _isInitialized = speechAvailable;
      return _isInitialized;
    } catch (e) {
      debugPrint('Voice service initialization error: $e');
      return false;
    }
  }
  
  /// Start listening for voice input
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isListening) return;
    
    _isListening = true;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          _isListening = false;
        } else if (onPartialResult != null) {
          onPartialResult(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
    );
  }
  
  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }
  
  /// Speak text using TTS
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isSpeaking) {
      await stop();
    }
    
    _isSpeaking = true;
    await _tts.speak(text);
    _isSpeaking = false;
  }
  
  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }
  
  /// Get available voices
  Future<List<Map<String, String>>> getAvailableVoices() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        return voices.map((v) => Map<String, String>.from(v as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting voices: $e');
      return [];
    }
  }
  
  /// Set voice by ID
  Future<void> setVoice(String voiceId) async {
    try {
      await _tts.setVoice({'name': voiceId, 'locale': 'en-US'});
      
      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySelectedVoice, voiceId);
    } catch (e) {
      debugPrint('Error setting voice: $e');
    }
  }
  
  /// Get recommended voice based on gender
  Future<String?> getRecommendedVoice(String? gender) async {
    final voices = await getAvailableVoices();
    if (voices.isEmpty) return null;
    
    // Filter by gender preference
    final genderLower = gender?.toLowerCase() ?? 'neutral';
    
    // Try to find matching voice
    for (var voice in voices) {
      final name = voice['name']?.toLowerCase() ?? '';
      
      if (genderLower == 'male' && (name.contains('male') || name.contains('man'))) {
        return voice['name'];
      } else if (genderLower == 'female' && (name.contains('female') || name.contains('woman'))) {
        return voice['name'];
      }
    }
    
    // Fallback to first available voice
    return voices.isNotEmpty ? voices.first['name'] : null;
  }
  
  /// Load saved voice preference
  Future<void> _loadVoicePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVoice = prefs.getString(_keySelectedVoice);
      if (savedVoice != null) {
        await setVoice(savedVoice);
      }
    } catch (e) {
      debugPrint('Error loading voice preference: $e');
    }
  }
  
  /// Get auto-speak preference
  Future<bool> getAutoSpeakEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoSpeak) ?? true; // Default to enabled
  }
  
  /// Set auto-speak preference
  Future<void> setAutoSpeakEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSpeak, enabled);
  }
  
  // Getters
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;
}
