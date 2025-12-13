import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ElevenLabsProvider {
  final String _baseUrl = 'https://api.elevenlabs.io/v1';
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _apiKey;
  bool _isAudioSessionConfigured = false;
  
  // Default "Sexy/Warm" voices
  // Rachel: 21m00Tcm4TlvDq8ikWAM (American, calm, young)
  // Josh: TxGEqnHWrfWFTfGW9XjX (American, deep, calm)
  // Bella: EXAVITQu4vr4xnSDxMaL (American, soft, intense)
  // Antoni: ErXwobaYiN019PkySvjV (American, well-rounded)
  String _currentVoiceId = 'EXAVITQu4vr4xnSDxMaL'; // Bella (Soft/Intense)

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  String get currentVoiceId => _currentVoiceId;
  
  /// Ensure audio session is configured for iOS/iPad playback
  Future<void> _ensureAudioSessionConfigured() async {
    if (_isAudioSessionConfigured) return;
    
    try {
      // Configure audio context for iOS/iPad to prevent crashes
      await _audioPlayer.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          audioMode: AndroidAudioMode.normal,
          stayAwake: false,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
      _isAudioSessionConfigured = true;
      debugPrint('✅ Audio session configured for voice playback');
    } catch (e) {
      debugPrint('⚠️ Failed to configure audio session: $e');
      // Continue anyway - may work on some devices
    }
  }

  void setApiKey(String key) {
    _apiKey = key;
  }

  void setVoiceId(String voiceId) {
    _currentVoiceId = voiceId;
  }

  /// Stream audio from text
  Future<void> speak(String text) async {
    if (!isConfigured) {
      debugPrint('ElevenLabs not configured, skipping.');
      return;
    }
    
    // Configure audio session for iOS/iPad BEFORE playing
    await _ensureAudioSessionConfigured();

    try {
      // Stop any current playback
      await _audioPlayer.stop();

      final url = Uri.parse('$_baseUrl/text-to-speech/$_currentVoiceId/stream');
      
      final request = http.Request('POST', url);
      request.headers.addAll({
        'xi-api-key': _apiKey!,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      });
      
      request.body = jsonEncode({
        "text": text,
        "model_id": "eleven_turbo_v2_5", // Turbo v2.5 (Low latency, high quality - "v3")
        "voice_settings": {
          "stability": 0.5,
          "similarity_boost": 0.75,
          "style": 0.0, // Turbo models don't support style as well, keep neutral
          "use_speaker_boost": true
        }
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        // We need to save the stream to a file to play it with audioplayers
        // (Direct streaming support varies by platform/package version)
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_stream.mp3');
        
        // Delete if exists
        if (await file.exists()) {
          await file.delete();
        }

        // Write stream to file
        final sink = file.openWrite();
        await response.stream.pipe(sink);
        await sink.close();

        // Play the file
        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        final body = await response.stream.bytesToString();
        debugPrint('ElevenLabs Error: ${response.statusCode} - $body');
      }
    } catch (e) {
      debugPrint('Error streaming ElevenLabs audio: $e');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
  
  /// Play audio from a URL (for voice previews)
  Future<void> playFromUrl(String url) async {
    try {
      // Stop any current playback
      await _audioPlayer.stop();
      
      // Play directly from URL
      await _audioPlayer.play(UrlSource(url));
      debugPrint('🔊 Playing audio from URL: $url');
    } catch (e) {
      debugPrint('Error playing from URL: $e');
      rethrow;
    }
  }

  /// Stream text to speech with specific voice and API key (for previews)
  Future<void> streamTextToSpeech({
    required String text,
    required String voiceId,
    required String apiKey,
  }) async {
    try {
      // Stop any current playback
      await _audioPlayer.stop();

      final url = Uri.parse('$_baseUrl/text-to-speech/$voiceId/stream');
      
      final request = http.Request('POST', url);
      request.headers.addAll({
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      });
      
      request.body = jsonEncode({
        "text": text,
        "model_id": "eleven_turbo_v2_5",
        "voice_settings": {
          "stability": 0.5,
          "similarity_boost": 0.75,
          "style": 0.0,
          "use_speaker_boost": true
        }
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_preview.mp3');
        
        // Delete if exists
        if (await file.exists()) {
          await file.delete();
        }
        
        final sink = file.openWrite();
        await response.stream.pipe(sink);
        await sink.close();

        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        debugPrint('Failed to stream preview: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error streaming preview: $e');
    }
  }
}
