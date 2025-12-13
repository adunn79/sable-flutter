import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sable/core/voice/eleven_labs_provider.dart';
import 'package:sable/core/voice/elevenlabs_api_service.dart';

/// Service for voice input (STT) and output (TTS)
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ElevenLabsProvider _elevenLabs = ElevenLabsProvider();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _speechAvailable = false; // Track if STT was actually initialized
  
  // Configuration keys
  static const String _keySelectedVoice = 'selected_voice_id';
  static const String _keyAutoSpeak = 'auto_speak'; // Matches SettingsControlService
  static const String _keyVoiceEngine = 'voice_engine_type'; // 'system' or 'eleven_labs'
  static const String _keyElevenLabsApiKey = 'eleven_labs_api_key';
  
  // Voice Engine State
  String _voiceEngine = 'eleven_labs'; // Default to ElevenLabs
  
  /// Initialize the voice service
  /// Only initializes speech-to-text if microphone permission was already granted
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Check if microphone permission was granted during onboarding
      // If not granted, skip STT initialization to avoid OS permission dialog
      final micStatus = await Permission.microphone.status;
      final speechStatus = await Permission.speech.status;
      
      bool speechAvailable = false;
      
      if (micStatus.isGranted && speechStatus.isGranted) {
        // Permission already granted - safe to initialize STT
        speechAvailable = await _speech.initialize(
          onError: (error) => debugPrint('Speech error: $error'),
          onStatus: (status) => debugPrint('Speech status: $status'),
        );
        _speechAvailable = speechAvailable;
        debugPrint('✅ Speech-to-text initialized: $speechAvailable');
      } else {
        debugPrint('⚠️ Skipping STT init: mic=${micStatus.isGranted}, speech=${speechStatus.isGranted}');
        // TTS can still work without STT permissions
        speechAvailable = false;
      }
      
      // Initialize text-to-speech with enhanced settings (always safe)
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
      
      // TTS is always available, STT depends on permission
      _isInitialized = true;
      return speechAvailable;
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
    if (!_speechAvailable) {
      debugPrint('⚠️ Speech not available - cannot listen');
      return;
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
  
  /// Listen for speech and return the recognized text (Future-based)
  /// Use this for simple one-shot speech recognition
  Future<String?> listenForSpeech({Duration timeout = const Duration(seconds: 30)}) async {
    if (!_isInitialized) await initialize();
    if (!_speechAvailable) {
      debugPrint('⚠️ Speech not available - cannot listen');
      return null;
    }
    if (_isListening) return null;
    
    final completer = Completer<String?>();
    
    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult && !completer.isCompleted) {
            completer.complete(result.recognizedWords);
            _isListening = false;
          }
        },
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
      );
      
      // Timeout fallback
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
          stopListening();
        }
      });
      
      return await completer.future;
    } catch (e) {
      debugPrint('Speech listen error: $e');
      _isListening = false;
      return null;
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
        debugPrint('🗣️ Speaking with ElevenLabs. Voice ID: ${_elevenLabs.currentVoiceId}');
        await _elevenLabs.speak(text);
      } else {
        // Fallback to System TTS
        debugPrint('🗣️ Speaking with System TTS');
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
  
  /// Speak text with a specific voice (for previews)
  Future<void> speakWithVoice(String text, {required String voiceId}) async {
    if (!_isInitialized) await initialize();
    if (_isSpeaking) await stop();
    
    _isSpeaking = true;
    
    try {
      if (_voiceEngine == 'eleven_labs' && _elevenLabs.isConfigured) {
        // Use ElevenLabs with specific voice
        final apiKey = await _getElevenLabsApiKey();
        if (apiKey != null) {
          await _elevenLabs.streamTextToSpeech(
            text: text,
            voiceId: voiceId,
            apiKey: apiKey,
          );
        }
      } else {
        // Use system TTS with specific voice
        await _tts.setVoice({'name': voiceId, 'locale': 'en-US'});
        await _tts.speak(text);
      }
    } catch (e) {
      debugPrint('Error speaking with voice: $e');
      _isSpeaking = false;
    }
    
    // Reset speaking flag after estimated duration
    Future.delayed(Duration(seconds: (text.length / 10).ceil()), () {
      _isSpeaking = false;
    });
  }
  
  /// Get ElevenLabs API key from preferences
  Future<String?> _getElevenLabsApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyElevenLabsApiKey);
  }
  
  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
    await _elevenLabs.stop();
    _isSpeaking = false;
  }
  
  /// Play audio from a URL (for voice previews)
  Future<void> playFromUrl(String url) async {
    if (!_isInitialized) await initialize();
    if (_isSpeaking) await stop();
    
    _isSpeaking = true;
    
    try {
      // Use ElevenLabs provider which has audio player capability
      await _elevenLabs.playFromUrl(url);
    } catch (e) {
      debugPrint('Error playing from URL: $e');
      _isSpeaking = false;
      rethrow;
    }
    
    // Reset speaking flag after estimated duration
    Future.delayed(const Duration(seconds: 5), () {
      _isSpeaking = false;
    });
  }
  
  /// Get curated list of high-quality voices (2M, 2F, 2N)
  /// ONLY returns ElevenLabs voices - no system voice fallback
  Future<List<Map<String, String>>> getCuratedVoices() async {
    if (!_isInitialized) await initialize();
    
    // The 6 ElevenLabs Personas - Standard Quality (Lower Bitrate)
    return [
      {'name': 'Josh (Male)', 'id': 'TxGEqnHWrfWFTfGW9XjX', 'category': 'Male'},
      {'name': 'Antoni (Male)', 'id': 'ErXwobaYiN019PkySvjV', 'category': 'Male'},
      {'name': 'Rachel (Female)', 'id': '21m00Tcm4TlvDq8ikWAM', 'category': 'Female'},
      {'name': 'Bella (Female)', 'id': 'EXAVITQu4vr4xnSDxMaL', 'category': 'Female'},
      {'name': 'Adam (Neutral)', 'id': 'pNInz6obpgDQGcFmaJgB', 'category': 'Neutral'},
      {'name': 'Mimi (Neutral)', 'id': 'zrHiDhphv9ZnVXBqCLjz', 'category': 'Neutral'},
    ];
  }

  /// Get all available voices (ElevenLabs)
  Future<List<VoiceWithMetadata>> getAllVoices() async {
    final apiService = ElevenLabsApiService();
    return await apiService.getAllVoices();
  }

  /// Get available voices (System or ElevenLabs)
  Future<List<Map<String, String>>> getAvailableVoices() async {
    if (!_isInitialized) await initialize();
    
    if (_voiceEngine == 'eleven_labs' && _elevenLabs.isConfigured) {
      // Return curated voices instead of calling the API
      // This avoids the "voices_read" permission requirement
      return await getCuratedVoices();
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
    final voices = await getCuratedVoices();
    if (voices.isEmpty) return null;
    
    // Filter by gender preference
    final genderLower = gender?.toLowerCase() ?? 'neutral';
    
    // Try to find matching voice
    for (var voice in voices) {
      final name = voice['name']?.toLowerCase() ?? '';
      
      if (genderLower == 'male' && (name.contains('male') || name.contains('man') || name.contains('josh') || name.contains('adam') || name.contains('clyde'))) {
        return voice['name'];
      } else if (genderLower == 'female' && (name.contains('female') || name.contains('woman') || name.contains('bella') || name.contains('nicole') || name.contains('mimi'))) {
        return voice['name'];
      }
    }
    
    // Fallback to first available voice
    return voices.isNotEmpty ? voices.first['name'] : null;
  }

  /// Get best voice ID for a specific gender (Male/Female/Neutral)
  String getBestVoiceForGender(String gender) {
    // ElevenLabs IDs (Standard Quality)
    // Josh (Male)
    const maleId = 'TxGEqnHWrfWFTfGW9XjX'; 
    // Rachel (Female)
    const femaleId = '21m00Tcm4TlvDq8ikWAM';
    // Adam (Neutral/Male-leaning) -> Or Mimi (Female-leaning)? 
    // Echo is "Reflective/Mirror" -> Adam is good.
    const neutralId = 'pNInz6obpgDQGcFmaJgB'; 

    switch (gender.toLowerCase()) {
      case 'male':
        return maleId;
      case 'female':
        return femaleId;
      case 'neutral':
      default:
        return neutralId;
    }
  }

  /// Get best voice ID for a specific archetype
  /// Returns culturally appropriate voices for Imani and Priya
  String getBestVoiceForArchetype(String archetypeId) {
    switch (archetypeId.toLowerCase()) {
      // IMANI - African American female voice
      // DrRenetta Weaver - African-American professional female
      case 'imani':
        return 'OYKPYtxX4mV3MAOiYkYc';
      
      // PRIYA - Indian female voice  
      // Anika - Hindi/Indian female voice
      case 'priya':
        return 'RABOvaPec1ymXz02oDQi';
      
      // AELIANA - Default flagship female (Rachel)
      case 'aeliana':
        return '21m00Tcm4TlvDq8ikWAM';
      
      // SABLE - Female (Bella - warm female)
      case 'sable':
        return 'EXAVITQu4vr4xnSDxMaL';
      
      // MARCO - Hispanic/Latino male with Mexican accent
      // Latino Gentleman - Spanish/Mexican accent narrator
      case 'marco':
        return 'UOsudtiwQVrIvIRyyCHn';
      
      // KAI - African American male
      // Hakeem - African American male narrator
      case 'kai':
        return 'nJvj5shg2xu1GKGxqfkE';
      
      // ECHO - Neutral (Adam)
      case 'echo':
        return 'pNInz6obpgDQGcFmaJgB';
      
      default:
        return '21m00Tcm4TlvDq8ikWAM'; // Default to Rachel
    }
  }
  
  /// Set voice by ID
  Future<void> setVoice(String voiceId) async {
    debugPrint('🎙️ Setting voice to: $voiceId');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedVoice, voiceId);
    
    if (_voiceEngine == 'eleven_labs') {
      _elevenLabs.setVoiceId(voiceId);
      debugPrint('✅ ElevenLabs voice set to: $voiceId');
    } else {
      await _tts.setVoice({'name': voiceId, 'locale': 'en-US'});
      debugPrint('✅ System voice set to: $voiceId');
    }
  }
  
  Future<void> setEngine(String engine) async {
    await setVoiceEngine(engine);
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
      
      // Load Engine - FORCE to eleven_labs (override any old 'system' preference)
      final savedEngine = prefs.getString(_keyVoiceEngine);
      debugPrint('🎙️ Saved engine preference: $savedEngine');
      
      if (savedEngine == 'system') {
        debugPrint('⚠️ Overriding old "system" preference to "eleven_labs"');
        _voiceEngine = 'eleven_labs';
        await prefs.setString(_keyVoiceEngine, 'eleven_labs');
      } else {
        _voiceEngine = savedEngine ?? 'eleven_labs';
      }
      
      debugPrint('✅ Current engine set to: $_voiceEngine');
      
      // Load API Key
      final apiKey = prefs.getString(_keyElevenLabsApiKey);
      if (apiKey != null) {
        _elevenLabs.setApiKey(apiKey);
        debugPrint('✅ ElevenLabs API key loaded');
      } else {
        debugPrint('⚠️ No ElevenLabs API key found in preferences');
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
    return prefs.getBool(_keyAutoSpeak) ?? false; // Default to OFF
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
