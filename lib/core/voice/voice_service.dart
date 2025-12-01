import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sable/core/voice/eleven_labs_provider.dart';

/// Service for voice input (STT) and output (TTS)
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ElevenLabsProvider _elevenLabs = ElevenLabsProvider();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  
  // Configuration keys
  static const String _keySelectedVoice = 'selected_voice_id';
  static const String _keyAutoSpeak = 'auto_speak_enabled';
  static const String _keyVoiceEngine = 'voice_engine_type'; // 'system' or 'eleven_labs'
  static const String _keyElevenLabsApiKey = 'eleven_labs_api_key';
  
  // Voice Engine State
  String _voiceEngine = 'system'; // Default to system
  
  /// Initialize the voice service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Initialize speech-to-text
      final speechAvailable = await _speech.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) => debugPrint('Speech status: $status'),
      );
      
      // Initialize text-to-speech with enhanced settings
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.52); // Slightly faster, more natural
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.05); // Slightly higher pitch for warmth
      
      // iOS-specific settings for better quality
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setVoice({
          'name': 'com.apple.voice.enhanced.en-US.Samantha',
          'locale': 'en-US'
        });
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      
      // Load preferences
      await _loadPreferences();
      
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
    if (!_isInitialized) await initialize();
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
  
  /// Speak text using selected engine
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    if (_isSpeaking) await stop();
    
    _isSpeaking = true;
    
    try {
      if (_voiceEngine == 'eleven_labs' && _elevenLabs.isConfigured) {
        // Use ElevenLabs
        await _elevenLabs.speak(text);
      } else {
        // Fallback to System TTS
        await _tts.speak(text);
      }
    } catch (e) {
      debugPrint('Error speaking: $e');
      _isSpeaking = false;
    }
    
    // Note: _isSpeaking logic for ElevenLabs is approximate as it's fire-and-forget currently
    // Ideally we'd listen to audio player completion events
    if (_voiceEngine == 'system') {
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });
    } else {
      // Simple timeout fallback for now
      Future.delayed(Duration(seconds: (text.length / 10).ceil()), () {
        _isSpeaking = false;
      });
    }
  }
  
  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
    await _elevenLabs.stop();
    _isSpeaking = false;
  }
  
  /// Get available voices (System or ElevenLabs)
  Future<List<Map<String, String>>> getAvailableVoices() async {
    if (!_isInitialized) await initialize();
    
    if (_voiceEngine == 'eleven_labs' && _elevenLabs.isConfigured) {
      try {
        final voices = await _elevenLabs.getVoices();
        return voices.map((v) => {
          'name': v['name'].toString(),
          'id': v['voice_id'].toString(),
          'locale': 'en-US'
        }).toList();
      } catch (e) {
        debugPrint('Error getting ElevenLabs voices: $e');
        return [];
      }
    } else {
      // System voices - Filter out sound effects
      try {
        final voices = await _tts.getVoices;
        if (voices is List) {
          final allVoices = voices.map((v) => Map<String, String>.from(v as Map)).toList();
          
          // Filter: Keep only actual voices, exclude sound effects
          final filteredVoices = allVoices.where((voice) {
            final name = voice['name']?.toLowerCase() ?? '';
            
            // Exclude sound effects (Bells, Boing, Bubbles, etc.)
            final soundEffects = ['bad news', 'good news', 'bells', 'boing', 'bubbles', 
                                   'cellos', 'wobble', 'superstar', 'organ', 'trinoids', 
                                   'zarvox', 'bahh', 'jester', 'fred'];
            
            if (soundEffects.any((effect) => name.contains(effect))) {
              return false;
            }
            
            // Keep voices (usually have locale like en-US, or recognizable human names)
            return true;
          }).toList();
          
          return filteredVoices;
        }
        return [];
      } catch (e) {
        debugPrint('Error getting system voices: $e');
        return [];
      }
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
      
      if (genderLower == 'male' && (name.contains('male') || name.contains('man') || name.contains('josh'))) {
        return voice['name'];
      } else if (genderLower == 'female' && (name.contains('female') || name.contains('woman') || name.contains('bella'))) {
        return voice['name'];
      }
    }
    
    // Fallback to first available voice
    return voices.isNotEmpty ? voices.first['name'] : null;
  }
  
  /// Set voice by ID
  Future<void> setVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedVoice, voiceId);
    
    if (_voiceEngine == 'eleven_labs') {
      _elevenLabs.setVoiceId(voiceId);
    } else {
      await _tts.setVoice({'name': voiceId, 'locale': 'en-US'});
    }
  }
  
  /// Set Voice Engine ('system' or 'eleven_labs')
  Future<void> setVoiceEngine(String engine) async {
    _voiceEngine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVoiceEngine, engine);
  }
  
  /// Set ElevenLabs API Key
  Future<void> setElevenLabsApiKey(String apiKey) async {
    _elevenLabs.setApiKey(apiKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyElevenLabsApiKey, apiKey);
  }
  
  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Engine
      _voiceEngine = prefs.getString(_keyVoiceEngine) ?? 'system';
      
      // Load API Key
      final apiKey = prefs.getString(_keyElevenLabsApiKey);
      if (apiKey != null) {
        _elevenLabs.setApiKey(apiKey);
      }
      
      // Load Voice
      final savedVoice = prefs.getString(_keySelectedVoice);
      if (savedVoice != null) {
        if (_voiceEngine == 'eleven_labs') {
          _elevenLabs.setVoiceId(savedVoice);
        } else {
          await _tts.setVoice({'name': savedVoice, 'locale': 'en-US'});
        }
      }
    } catch (e) {
      debugPrint('Error loading voice preferences: $e');
    }
  }
  
  /// Get auto-speak preference
  Future<bool> getAutoSpeakEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoSpeak) ?? true;
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
  String get currentEngine => _voiceEngine;
  bool get isElevenLabsConfigured => _elevenLabs.isConfigured;
}
