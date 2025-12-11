import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';

import '../services/journal_storage_service.dart';
import '../models/journal_entry.dart';
import '../models/journal_bucket.dart';
import '../services/music_service.dart';
import '../widgets/avatar_journal_overlay.dart';
import '../widgets/template_picker_sheet.dart';
import '../widgets/prompt_picker_sheet.dart';
import '../models/journal_template.dart';
import 'package:sable/core/voice/voice_service.dart';
import 'package:sable/core/emotion/location_service.dart';
import 'package:sable/core/emotion/weather_service.dart';
import 'package:sable/core/ai/providers/gemini_provider.dart';
import 'package:sable/core/ai/model_orchestrator.dart'; // IMPORTED
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Need for ConsumerStatefulWidget
import 'package:sable/src/config/app_config.dart';
import 'package:sable/core/photos/widgets/photo_picker_sheet.dart';
import 'package:sable/core/media/now_playing_service.dart';
import 'package:sable/core/news/headline_service.dart';

/// Rich text journal editor with privacy toggle, mood, and tags
class JournalEditorScreen extends StatefulWidget {
  final String? entryId; // null for new entry
  final String bucketId;
  final String? aiPrompt; // Pre-filled AI prompt for assisted journaling

  const JournalEditorScreen({
    super.key,
    this.entryId,
    required this.bucketId,
    this.aiPrompt,
  });

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  late QuillController _quillController;
  late FocusNode _focusNode;
  late ScrollController _editorScrollController; // Persistent scroll controller for editor
  
  bool _isPrivate = false;
  int? _moodScore;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();
  
  JournalBucket? _bucket;
  JournalEntry? _existingEntry;
  bool _isLoading = true;
  bool _isSaving = false;
  String _archetype = 'sable'; // Current avatar for overlay
  
  // Voice dictation
  VoiceService? _voiceService;
  bool _isListening = false;
  
  // P1+ Memory Fields
  String? _nowPlayingTrack;
  String? _nowPlayingArtist;
  List<String> _taggedPeople = [];
  bool _isGroupActivity = false;
  String? _topHeadline;
  
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _editorScrollController = ScrollController(); // Persistent scroll controller
    _initVoice();
    _loadData();
  }
  
  Future<void> _loadData() async {
    _bucket = JournalStorageService.getBucket(widget.bucketId);
    
    // Load current archetype for avatar overlay
    final prefs = await SharedPreferences.getInstance();
    _archetype = prefs.getString('selected_archetype_id') ?? 'sable';
    
    if (widget.entryId != null) {
      // Editing existing entry
      _existingEntry = JournalStorageService.getEntry(widget.entryId!);
      if (_existingEntry != null) {
        // Parse existing content
        try {
          final doc = Document.fromJson(jsonDecode(_existingEntry!.content));
          _quillController = QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } catch (e) {
          // Fallback if content isn't valid JSON
          _quillController = QuillController.basic();
          _quillController.document.insert(0, _existingEntry!.plainText);
        }
        _isPrivate = _existingEntry!.isPrivate;
        _moodScore = _existingEntry!.moodScore;
        _tags = List.from(_existingEntry!.tags);
        // Load existing P1+ data
        _nowPlayingTrack = _existingEntry!.nowPlayingTrack;
        _nowPlayingArtist = _existingEntry!.nowPlayingArtist;
        _taggedPeople = List.from(_existingEntry!.taggedPeople ?? []);
        _isGroupActivity = _existingEntry!.isGroupActivity ?? false;
        _topHeadline = _existingEntry!.topHeadline;
      } else {
        _quillController = QuillController.basic();
      }
    } else {
      // New entry
      _quillController = QuillController.basic();
      // If AI prompt provided, insert it as starter text
      if (widget.aiPrompt != null && widget.aiPrompt!.isNotEmpty) {
        _quillController.document.insert(0, widget.aiPrompt!);
        // Move cursor to end of prompt
        _quillController.updateSelection(
          TextSelection.collapsed(offset: widget.aiPrompt!.length),
          ChangeSource.local,
        );
      }
      // Default privacy based on bucket settings
      _isPrivate = _bucket?.isVault ?? !(_bucket?.avatarAccessDefault ?? true);
      
      // Auto-capture Now Playing music and Top Headline for new entries
      _captureNowPlaying();
      _fetchHeadline();
    }
    
    setState(() => _isLoading = false);
    
    // Focus the editor after a small delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }
  
  /// Auto-capture currently playing music
  Future<void> _captureNowPlaying() async {
    try {
      final nowPlaying = await NowPlayingService.getCurrentTrack();
      if (nowPlaying != null && mounted) {
        setState(() {
          _nowPlayingTrack = nowPlaying.title;
          _nowPlayingArtist = nowPlaying.artist;
        });
        debugPrint('🎵 Journal: Captured now playing: ${nowPlaying.title} - ${nowPlaying.artist}');
      }
    } catch (e) {
      debugPrint('🎵 Now playing capture failed: $e');
    }
  }

  /// Show music dialog: Auto-detect or Manual Search
  void _showMusicDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Add Music', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.music, color: Colors.green),
              title: const Text('Auto-Detect Playing', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Capture from Spotify/Apple Music', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _captureNowPlaying();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.search, color: Colors.blue),
              title: const Text('Manual Search', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Search by song title', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showMusicSearchDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMusicSearchDialog() {
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Search Song', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Song Title...',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(LucideIcons.search, color: Colors.white54),
                  ),
                  onSubmitted: (query) async {
                    // In a real app, this would update a list in the state
                    // For now we just pick the first result to simulate
                    final results = await MusicService.searchTrack(query);
                    if (results.isNotEmpty && mounted) {
                      setState(() {
                         _nowPlayingTrack = results.first['track'];
                         _nowPlayingArtist = results.first['artist'];
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Enter title and press Enter', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          );
        }
      ),
    );
  }
  
  /// Auto-fetch today's top headline
  Future<void> _fetchHeadline() async {
    try {
      final headline = await HeadlineService.getTopHeadline();
      if (headline != null && mounted) {
        setState(() {
          _topHeadline = headline;
        });
        debugPrint('📰 Journal: Headline captured: $headline');
      }
    } catch (e) {
      debugPrint('📰 Headline fetch failed: $e');
    }
  }
  
  @override
  void dispose() {
    _quillController.dispose();
    _focusNode.dispose();
    _tagController.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }
  
  Future<void> _initVoice() async {
    _voiceService = VoiceService();
    await _voiceService!.initialize();
  }
  
  Future<void> _toggleVoiceDictation() async {
    if (_voiceService == null) return;
    
    if (_isListening) {
      // Stop listening
      await _voiceService!.stopListening();
      setState(() => _isListening = false);
    } else {
      // Start listening
      setState(() => _isListening = true);
      
      await _voiceService!.startListening(
        onResult: (text) {
          // Insert dictated text at cursor position
          final index = _quillController.selection.baseOffset;
          _quillController.document.insert(index, text + ' ');
          _quillController.updateSelection(
            TextSelection.collapsed(offset: index + text.length + 1),
            ChangeSource.local,
          );
          setState(() => _isListening = false);
        },
        onPartialResult: (text) {
          // Show partial text in a snackbar or overlay
          debugPrint('🎤 Partial: $text');
        },
      );
    }
  }
  
  Future<void> _generateSparkPrompt() async {
    final currentText = _quillController.document.toPlainText().trim();
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('✨ Generating prompt...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );
    
    try {
      final gemini = GeminiProvider();
      final systemPrompt = '''
You are a gentle, empathetic journaling coach in a private journaling app. 
Your role is to provide ONE short, thoughtful prompt to help the user explore their thoughts more deeply.

Guidelines:
- Be warm, curious, and non-judgmental
- Ask ONE open-ended question or offer ONE gentle reflection
- Keep it VERY short (1-2 sentences max)
- Use phrases like "I notice...", "What might...", "How did that..."
- Never be preachy or give advice
- If the entry mentions emotions, gently explore them
- If the entry is empty, give a gentle starting prompt
''';

      String userPrompt;
      if (currentText.isEmpty) {
        userPrompt = 'The user just opened their journal and hasn\'t written anything yet. Give them a gentle, open-ended prompt to start writing.';
      } else {
        userPrompt = 'The user is writing this journal entry:\n\n"$currentText"\n\nGive them ONE short, empathetic prompt to help them explore this further.';
      }
      
      final response = await gemini.generateResponse(
        prompt: userPrompt,
        systemPrompt: systemPrompt,
        modelId: 'gemini-2.0-flash-exp',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSparkPromptDialog(response);
      }
    } catch (e) {
      debugPrint('Spark error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✨ Spark unavailable: $e')),
        );
      }
    }
  }
  
  void _showSparkPromptDialog(String prompt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _JournalChatSheet(
        initialPrompt: prompt,
        archetype: _archetype,
        journalContext: _quillController.document.toPlainText().trim(),
      ),
    );
  }
  
  Future<void> _saveEntry() async {
    if (_isSaving) return;
    
    final plainText = _quillController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save empty entry')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final content = jsonEncode(_quillController.document.toDelta().toJson());
      
      // Auto-capture location for new entries
      Position? position;
      String? locationName;
      String? weather;
      if (_existingEntry == null) {
        position = await LocationService.getCurrentPosition();
        // Get city name from coordinates using reverse geocoding
        final apiKey = AppConfig.googleKey;
        
        // Try to get location name from geocoding
        if (apiKey.isNotEmpty && position != null) {
          locationName = await LocationService.getCurrentLocationName(apiKey);
        }
        // Fallback to cached GPS location if geocoding failed
        if (locationName == null || locationName.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          locationName = prefs.getString('gps_location') ?? prefs.getString('manual_location');
        }
        
        // Auto-capture weather using coordinates
        if (position != null) {
          try {
            final weatherCondition = await WeatherService.getWeatherByCoords(
              position.latitude, 
              position.longitude,
            );
            if (weatherCondition != null) {
              weather = '${weatherCondition.description}, ${weatherCondition.temperature.round()}°F';
            }
          } catch (e) {
            debugPrint('🌤️ Weather capture failed: $e');
          }
        }
        
        debugPrint('📍 Journal: $locationName | 🌤️ $weather');
      }
      
      if (_existingEntry != null) {
        // Update existing
        await JournalStorageService.updateEntry(
          _existingEntry!.copyWith(
            content: content,
            plainText: plainText,
            isPrivate: _isPrivate,
            moodScore: _moodScore,
            tags: _tags,
          ),
        );
      } else {
        // Create new with location, weather, and P1+ fields
        await JournalStorageService.createEntry(
          content: content,
          plainText: plainText,
          bucketId: widget.bucketId,
          isPrivate: _isPrivate,
          moodScore: _moodScore,
          tags: _tags,
          location: locationName,
          latitude: position?.latitude,
          longitude: position?.longitude,
          weather: weather,
          // P1+ Memory Fields
          nowPlayingTrack: _nowPlayingTrack,
          nowPlayingArtist: _nowPlayingArtist,
          taggedPeople: _taggedPeople,
          isGroupActivity: _isGroupActivity,
          topHeadline: _topHeadline,
        );
      }
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate save
      }
    } catch (e) {
      debugPrint('Error saving entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _tagController.clear();
      });
    }
  }
  
  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }
  
  Future<List<String>> _generateTagSuggestions() async {
    final content = _quillController.document.toPlainText().trim();
    if (content.isEmpty) {
      return ['personal', 'note', 'daily'];
    }
    
    try {
      final gemini = GeminiProvider();
      final response = await gemini.generateResponse(
        prompt: '''Based on this journal entry, suggest 5 relevant tags for organization.
        
Entry: "$content"

Return ONLY a comma-separated list of 5 short, lowercase tags (1-2 words each).
Example: angry, work, restaurant, frustration, food
No hashtags, no explanations, just the tags.''',
        systemPrompt: 'You are a tagging assistant. Return only comma-separated tags, nothing else.',
        modelId: 'gemini-2.0-flash-exp',
      );
      
      return response
          .split(',')
          .map((s) => s.trim().toLowerCase().replaceAll('#', ''))
          .where((s) => s.isNotEmpty && s.length < 20)
          .take(5)
          .toList();
    } catch (e) {
      debugPrint('Tag suggestion error: $e');
      return ['personal', 'journal', 'thought'];
    }
  }
  
  void _showTagDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _TagSuggestionDialog(
        onTagAdded: (tag) {
          _addTag(tag);
          Navigator.pop(ctx);
        },
        onClose: () => Navigator.pop(ctx),
        generateSuggestions: _generateTagSuggestions,
        tagController: _tagController,
      ),
    );
  }
  
  /// Show dialog for tagging people in this entry
  void _showPeopleTagDialog() {
    final peopleController = TextEditingController();
    // Common quick-add suggestions
    final suggestions = ['Mom', 'Dad', 'Partner', 'Friend', 'Coworker', 'Family'];
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(LucideIcons.users, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text('Tag People', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick suggestions
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions.map((person) {
                  final isAdded = _taggedPeople.contains(person);
                  return GestureDetector(
                    onTap: () {
                      if (!isAdded) {
                        setState(() => _taggedPeople.add(person));
                        setDialogState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAdded ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isAdded ? Colors.blue : Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdded) const Icon(LucideIcons.check, size: 14, color: Colors.blue),
                          if (isAdded) const SizedBox(width: 4),
                          Text(person, style: TextStyle(color: isAdded ? Colors.blue : Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Custom name input
              TextField(
                controller: peopleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add custom name...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  suffixIcon: IconButton(
                    icon: const Icon(LucideIcons.plus, color: Colors.blue),
                    onPressed: () {
                      final name = peopleController.text.trim();
                      if (name.isNotEmpty && !_taggedPeople.contains(name)) {
                        setState(() => _taggedPeople.add(name));
                        setDialogState(() {});
                        peopleController.clear();
                      }
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (value) {
                  final name = value.trim();
                  if (name.isNotEmpty && !_taggedPeople.contains(name)) {
                    setState(() => _taggedPeople.add(name));
                    setDialogState(() {});
                    peopleController.clear();
                  }
                },
              ),
              // Current tags display
              if (_taggedPeople.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Tagged:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _taggedPeople.map((p) => Chip(
                    label: Text(p, style: const TextStyle(fontSize: 11)),
                    deleteIcon: const Icon(LucideIcons.x, size: 14),
                    onDeleted: () {
                      setState(() => _taggedPeople.remove(p));
                      setDialogState(() {});
                    },
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.blue),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showMoodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How are you feeling?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMoodOption(1, '😢', 'Sad'),
                _buildMoodOption(2, '😔', 'Down'),
                _buildMoodOption(3, '😐', 'Okay'),
                _buildMoodOption(4, '🙂', 'Good'),
                _buildMoodOption(5, '😊', 'Great'),
              ],
            ),
            const SizedBox(height: 16),
            if (_moodScore != null)
              TextButton(
                onPressed: () {
                  setState(() => _moodScore = null);
                  Navigator.pop(ctx);
                },
                child: const Text('Clear mood'),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Show template picker and apply selected template
  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TemplatePickerSheet(
        onTemplateSelected: _applyTemplate,
      ),
    );
  }
  
  /// Apply template to editor by inserting formatted fields
  void _applyTemplate(JournalTemplate template) {
    // Clear current content if empty, otherwise add template after existing content
    final currentText = _quillController.document.toPlainText().trim();
    final startIndex = currentText.isEmpty ? 0 : _quillController.document.length - 1;
    
    // Build template text
    final buffer = StringBuffer();
    if (currentText.isNotEmpty) {
      buffer.writeln('\n\n'); // Space after existing content
    }
    
    // Add template name as header
    buffer.writeln('📋 ${template.name}\n');
    
    // Add each field with placeholder
    for (final field in template.fields) {
      buffer.writeln('${field.label}');
      if (field.placeholder.isNotEmpty) {
        buffer.writeln('${field.placeholder}\n');
      } else {
        buffer.writeln();
      }
    }
    
    // Insert into editor
    _quillController.document.insert(startIndex, buffer.toString());
    _quillController.updateSelection(
      TextSelection.collapsed(offset: startIndex + buffer.length),
      ChangeSource.local,
    );
    
    // Focus editor
    _focusNode.requestFocus();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ ${template.name} applied!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF5DD9C1),
      ),
    );
  }
  
  /// Show prompt picker and insert selected prompt
  void _showPromptPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PromptPickerSheet(
        onPromptSelected: (prompt) {
          // Insert prompt at cursor position
          final index = _quillController.selection.baseOffset;
          _quillController.document.insert(index, '\n$prompt\n\n');
          _quillController.updateSelection(
            TextSelection.collapsed(offset: index + prompt.length + 3),
            ChangeSource.local,
          );
          _focusNode.requestFocus();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Prompt added!'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFFB8A9D9),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildMoodOption(int score, String emoji, String label) {
    final isSelected = _moodScore == score;
    return GestureDetector(
      onTap: () {
        setState(() => _moodScore = score);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.grey,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHighlightedUndoRedo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Undo button - highlighted
        Tooltip(
          message: 'Undo - Fix typing mistakes',
          child: GestureDetector(
            onTap: () {
              if (_quillController.hasUndo) {
                _quillController.undo();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Icon(
                LucideIcons.undo, 
                size: 18, 
                color: _quillController.hasUndo ? Colors.amber : Colors.grey,
              ),
            ),
          ),
        ),
        // Redo button - highlighted
        Tooltip(
          message: 'Redo - Restore undone text',
          child: GestureDetector(
            onTap: () {
              if (_quillController.hasRedo) {
                _quillController.redo();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Icon(
                LucideIcons.redo, 
                size: 18, 
                color: _quillController.hasRedo ? Colors.amber : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoButton() {
    return Tooltip(
      message: 'Toolbar Help',
      child: GestureDetector(
        onTap: _showToolbarHelp,
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(right: 8),
          child: Icon(LucideIcons.info, size: 18, color: Colors.white.withOpacity(0.5)),
        ),
      ),
    );
  }
  
  void _showToolbarHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📝 Toolbar Guide',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHelpItem('🎤', 'Voice Dictate', 'Speak to type'),
              _buildHelpItem('↶ ↷', 'Undo/Redo', 'Fix mistakes (gold)'),
              _buildHelpItem('B', 'Bold', 'Make text bold'),
              _buildHelpItem('I', 'Italic', 'Italic text'),
              _buildHelpItem('U', 'Underline', 'Underline'),
              _buildHelpItem('❝', 'Quote', 'Quote block'),
              _buildHelpItem('•', 'Bullets', 'Bullet list'),
              _buildHelpItem('1.', 'Numbers', 'Numbered list'),
              _buildHelpItem('☑', 'Checklist', 'Tasks'),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it!', style: TextStyle(color: Colors.cyan, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHelpItem(String icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF050505),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final isVault = _bucket?.isVault ?? false;
    
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _bucket?.name ?? 'Journal',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          // Template button
          IconButton(
            icon: const Icon(LucideIcons.layoutTemplate, color: Color(0xFF5DD9C1)),
            tooltip: 'Use Template',
            onPressed: _showTemplatePicker,
          ),
          // Prompt button
          IconButton(
            icon: const Icon(LucideIcons.sparkles, color: Color(0xFFB8A9D9)),
            tooltip: 'Get Writing Prompt',
            onPressed: _showPromptPicker,
          ),
          // Privacy toggle (eye icon)
          if (!isVault) // Hide toggle for vault (always private)
            IconButton(
              icon: Icon(
                _isPrivate ? LucideIcons.eyeOff : LucideIcons.eye,
                color: _isPrivate ? Colors.red : Colors.green,
              ),
              tooltip: _isPrivate ? 'Private (Avatar cannot see)' : 'Visible to Avatar',
              onPressed: () => setState(() => _isPrivate = !_isPrivate),
            ),
          // Save button
          TextButton(
            onPressed: _isSaving ? null : _saveEntry,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Mood and tags bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Mood button
                      GestureDetector(
                    onTap: _showMoodPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _moodScore != null
                                ? ['😢', '😔', '😐', '🙂', '😊'][_moodScore! - 1]
                                : '😶',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _moodScore != null ? 'Mood' : 'Add mood',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tags
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._tags.map((tag) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                              deleteIcon: const Icon(LucideIcons.x, size: 14),
                              onDeleted: () => _removeTag(tag),
                              backgroundColor: Colors.white.withOpacity(0.1),
                              labelStyle: const TextStyle(color: Colors.white70),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )),
                          // Add tag button
                          GestureDetector(
                            onTap: _showTagDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.plus, size: 14, color: Colors.white.withOpacity(0.5)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tag',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // P1+ Metadata Row (Now Playing, Top Headline, People Tags)
            if (_nowPlayingTrack != null || _taggedPeople.isNotEmpty || _topHeadline != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Now Playing chip
                    if (_nowPlayingTrack != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.music, size: 12, color: Colors.green.shade400),
                            const SizedBox(width: 6),
                            Text(
                              '${_nowPlayingTrack!}${_nowPlayingArtist != null ? " - $_nowPlayingArtist" : ""}',
                              style: TextStyle(fontSize: 11, color: Colors.green.shade300),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() {
                                _nowPlayingTrack = null;
                                _nowPlayingArtist = null;
                              }),
                              child: Icon(LucideIcons.x, size: 12, color: Colors.green.shade400),
                            ),
                          ],
                        ),
                      ),
                    // Top Headline chip
                    if (_topHeadline != null)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.newspaper, size: 12, color: Colors.orange.shade400),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _topHeadline!,
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade300),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _topHeadline = null),
                              child: Icon(LucideIcons.x, size: 12, color: Colors.orange.shade400),
                            ),
                          ],
                        ),
                      ),
                    // People tags
                    ..._taggedPeople.map((person) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.user, size: 12, color: Colors.blue.shade400),
                          const SizedBox(width: 4),
                          Text(person, style: TextStyle(fontSize: 11, color: Colors.blue.shade300)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _taggedPeople.remove(person)),
                            child: Icon(LucideIcons.x, size: 12, color: Colors.blue.shade400),
                          ),
                        ],
                      ),
                    )),
                    // Group toggle if people tagged
                    if (_taggedPeople.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _isGroupActivity = !_isGroupActivity),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isGroupActivity ? Colors.purple.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _isGroupActivity ? Colors.purple : Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.users, size: 12, color: _isGroupActivity ? Colors.purple : Colors.white54),
                              const SizedBox(width: 4),
                              Text('Group', style: TextStyle(fontSize: 10, color: _isGroupActivity ? Colors.purple : Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            
            // Add People Button (always visible for easy tagging)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [

                  GestureDetector(
                    onTap: _showPeopleTagDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.userPlus, size: 14, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 6),
                          Text(
                            'Tag people',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add Music Button
                  if (_nowPlayingTrack == null)
                    GestureDetector(
                      onTap: _showMusicDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.music, size: 14, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 6),
                            Text(
                              'Add Song',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_nowPlayingTrack == null) const SizedBox(width: 8),
                  // Add Headline Button
                  if (_topHeadline == null)
                    GestureDetector(
                      onTap: _fetchHeadline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.newspaper, size: 14, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 6),
                            Text(
                              'Headline',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: QuillEditor.basic(
                  controller: _quillController,
                  config: QuillEditorConfig(
                    placeholder: 'Start writing...',
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    autoFocus: false, // Prevent auto-focus causing cursor issues
                    expands: false, // Don't expand to fill
                    showCursor: true,
                    enableInteractiveSelection: true,
                  ),
                ),
              ),
            ),
            
            // Toolbar with voice dictation
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  // Voice dictation button
                  GestureDetector(
                    onTap: _toggleVoiceDictation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Icon(
                        _isListening ? LucideIcons.micOff : LucideIcons.mic,
                        color: _isListening ? Colors.red : Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                  // Photo button
                  GestureDetector(
                    onTap: () async {
                      final photo = await PhotoPickerSheet.show(
                        context,
                        linkedJournalId: _existingEntry?.id,
                        showPrivateOption: true,
                      );
                      if (photo != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📷 Photo added${photo.isPrivate ? " (private)" : ""}'),
                            backgroundColor: photo.isPrivate ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: const Icon(
                        LucideIcons.camera,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  // HIGHLIGHTED Undo/Redo buttons
                  _buildHighlightedUndoRedo(),
                  // Divider
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  // Quill toolbar (formatting)
                  Expanded(
                    child: QuillSimpleToolbar(
                controller: _quillController,
                config: QuillSimpleToolbarConfig(
                  showFontFamily: false,
                  showFontSize: false,
                  showBackgroundColorButton: false,
                  showColorButton: false,
                  showClearFormat: false,
                  showHeaderStyle: false,
                  showIndent: false,
                  showLink: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showInlineCode: false,
                  showCodeBlock: false,
                  showQuote: true,
                  showListBullets: true,
                  showListNumbers: true,
                  showListCheck: true,
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: false,
                  showAlignmentButtons: false,
                  showUndo: false, // Using custom undo
                  showRedo: false, // Using custom redo
                ),
              ),
            ), // End Expanded
            // Info button
            _buildInfoButton(),
          ], // End Row children
        ), // End Row
      ), // End Container
          ], // End Column children
        ), // End Column
      ), // End SafeArea
      
      // Avatar overlay with privacy state
      Positioned(
        left: 16,
        bottom: 16,
        child: AvatarJournalOverlay(
          isPrivate: _isPrivate,
          archetype: _archetype,
          onSparkTap: null, // Removed - using avatar tap instead
          onAvatarTap: _isPrivate 
              ? () {
                  // When private, just show status
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_archetype[0].toUpperCase()}${_archetype.substring(1)} can\'t see this entry (private mode)'),
                      backgroundColor: Colors.grey[800],
                    ),
                  );
                }
              : _generateSparkPrompt, // When observing, trigger AI prompt
        ),
      ),
    ],
  ),
);
  }
}

/// Inline chat sheet for journal coaching
class _JournalChatSheet extends ConsumerStatefulWidget {
  final String initialPrompt;
  final String archetype;
  final String journalContext;
  
  const _JournalChatSheet({
    required this.initialPrompt,
    required this.archetype,
    required this.journalContext,
  });
  
  @override
  ConsumerState<_JournalChatSheet> createState() => _JournalChatSheetState();
}

class _JournalChatSheetState extends ConsumerState<_JournalChatSheet> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String _userName = '';
  String _userAge = '';
  String _userOrigin = '';
  
  @override
  void initState() {
    super.initState();
    _messages.add({'role': 'assistant', 'content': widget.initialPrompt});
    _loadUserProfile();
  }
  
  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
      _userAge = prefs.getString('user_age') ?? '';
      _userOrigin = prefs.getString('ai_origin') ?? '';
    });
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }
  
  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isLoading) return;
    
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _replyController.clear();
    _scrollToBottom();
    
    try {
      final gemini = GeminiProvider();
      final avatarName = widget.archetype[0].toUpperCase() + widget.archetype.substring(1);
      final systemPrompt = '''
You are $avatarName, a supportive companion in a private journaling app.
You are chatting with${_userName.isNotEmpty ? ' $_userName,' : ''} someone${_userAge.isNotEmpty ? ' who is $_userAge' : ''}${_userOrigin.isNotEmpty ? ' from $_userOrigin' : ''}.

Their journal entry: "${widget.journalContext}"

CRITICAL - Your tone must:
- Match their age and vocabulary (if young, be casual and relatable, not clinical)
- Sound like a supportive friend, NOT a therapist
- Use casual language: "that sucks", "I get it", "ugh", "honestly..."
- Keep responses SHORT (2-3 sentences MAX)
- Ask ONE follow-up question to explore feelings
- Never be preachy, formal, or give unsolicited advice
- Validate feelings first, always
''';

      final conversationHistory = _messages.map((m) => 
        '${m['role'] == 'user' ? 'User' : widget.archetype}: ${m['content']}'
      ).join('\n');
      
      final response = await gemini.generateResponse(
        prompt: 'Conversation so far:\n$conversationHistory\n\nRespond briefly and empathetically.',
        systemPrompt: systemPrompt,
        modelId: 'gemini-2.0-flash-exp',
      );
      
      // --- COMPILER HARDENING START ---
      final orchestrator = ref.read(modelOrchestratorProvider.notifier);
      final harmonizedResponse = await orchestrator.harmonizeResponse(
        response, 
        'Journal Context: ${widget.journalContext}',
        archetypeName: widget.archetype[0].toUpperCase() + widget.archetype.substring(1)
      );
      // --- COMPILER HARDENING END ---
      
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': harmonizedResponse});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Chat error: $e');
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'Sorry, I had trouble responding. Let me try again later.'});
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final avatarName = widget.archetype[0].toUpperCase() + widget.archetype.substring(1);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  '$avatarName is here to help',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(LucideIcons.x, color: Colors.grey[500], size: 20),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i >= _messages.length) {
                  // Loading indicator
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple[300]),
                          ),
                          const SizedBox(width: 8),
                          Text('$avatarName is thinking...', style: TextStyle(color: Colors.purple[300], fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue.withOpacity(0.3) : Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Input - with safe area for bottom nav
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 8, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 100,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Reply to $avatarName...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendReply(),
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _sendReply,
                  icon: Icon(
                    LucideIcons.send,
                    color: _isLoading ? Colors.grey : Colors.purple,
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

/// Dialog with AI-powered tag suggestions
class _TagSuggestionDialog extends StatefulWidget {
  final Function(String) onTagAdded;
  final VoidCallback onClose;
  final Future<List<String>> Function() generateSuggestions;
  final TextEditingController tagController;
  
  const _TagSuggestionDialog({
    required this.onTagAdded,
    required this.onClose,
    required this.generateSuggestions,
    required this.tagController,
  });
  
  @override
  State<_TagSuggestionDialog> createState() => _TagSuggestionDialogState();
}

class _TagSuggestionDialogState extends State<_TagSuggestionDialog> {
  List<String> _suggestions = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }
  
  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    final suggestions = await widget.generateSuggestions();
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Row(
        children: [
          const Text('Add Tag', style: TextStyle(color: Colors.white, fontSize: 18)),
          const Spacer(),
          if (_isLoading)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.tagController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter tag name',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixText: '#',
              prefixStyle: TextStyle(color: Colors.cyan[300]),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.cyan),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (value) => widget.onTagAdded(value),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '✨ Suggested tags:',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((tag) => GestureDetector(
                onTap: () => widget.onTagAdded(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.withOpacity(0.4)),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(color: Colors.purple[200], fontSize: 13),
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onClose,
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => widget.onTagAdded(widget.tagController.text),
          child: const Text('Add', style: TextStyle(color: Colors.cyan)),
        ),
      ],
    );
  }
}
