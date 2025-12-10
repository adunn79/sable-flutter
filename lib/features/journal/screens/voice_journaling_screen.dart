import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/journal_storage_service.dart';

/// Voice-to-Text Journaling Screen with live transcription
class VoiceJournalingScreen extends StatefulWidget {
  const VoiceJournalingScreen({super.key});

  @override
  State<VoiceJournalingScreen> createState() => _VoiceJournalingScreenState();
}

class _VoiceJournalingScreenState extends State<VoiceJournalingScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _transcribedText = '';
  double _confidence = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    setState(() => _isInitialized = available);
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    setState(() => _isListening = true);
    
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _transcribedText = result.recognizedWords;
          _confidence = result.confidence;
        });
      },
      listenMode: stt.ListenMode.dictation,
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _saveEntry() async {
    if (_transcribedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to save')),
      );
      return;
    }

    try {
      await JournalStorageService.createEntry(
        content: _transcribedText,
        plainText: _transcribedText,
        bucketId: '', // Default bucket
        tags: ['voice-entry'],
        isPrivate: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Voice entry saved!'),
            backgroundColor: Color(0xFF5DD9C1),
          ),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Voice Journal',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_transcribedText.isNotEmpty)
            TextButton(
              onPressed: _saveEntry,
              child: const Text('Save', style: TextStyle(color: Color(0xFF5DD9C1))),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isListening 
                  ? Colors.red.withOpacity(0.1) 
                  : const Color(0xFF1E2D3D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isListening ? Colors.red : Colors.white12,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isListening ? LucideIcons.mic : LucideIcons.micOff,
                  color: _isListening ? Colors.red : Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _isListening ? 'Listening...' : 'Tap to speak',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: _isListening ? Colors.red : Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_isListening && _confidence > 0) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${(_confidence * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Transcribed text
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2D3D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _transcribedText.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.mic,
                            size: 64,
                            color: Colors.white30,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Speak your thoughts',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your words will appear here',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Text(
                        _transcribedText,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.6,
                        ),
                      ),
                    ),
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_transcribedText.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _transcribedText = '');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.red : const Color(0xFF5DD9C1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isListening ? LucideIcons.square : LucideIcons.mic,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isListening ? 'Stop' : 'Start Recording',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
