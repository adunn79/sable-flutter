import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/journal_storage_service.dart';
import '../models/journal_entry.dart';
import '../models/journal_bucket.dart';
import '../widgets/avatar_journal_overlay.dart';

/// Rich text journal editor with privacy toggle, mood, and tags
class JournalEditorScreen extends StatefulWidget {
  final String? entryId; // null for new entry
  final String bucketId;

  const JournalEditorScreen({
    super.key,
    this.entryId,
    required this.bucketId,
  });

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  late QuillController _quillController;
  late FocusNode _focusNode;
  
  bool _isPrivate = false;
  int? _moodScore;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();
  
  JournalBucket? _bucket;
  JournalEntry? _existingEntry;
  bool _isLoading = true;
  bool _isSaving = false;
  String _archetype = 'sable'; // Current avatar for overlay
  
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
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
      } else {
        _quillController = QuillController.basic();
      }
    } else {
      // New entry
      _quillController = QuillController.basic();
      // Default privacy based on bucket settings
      _isPrivate = _bucket?.isVault ?? !(_bucket?.avatarAccessDefault ?? true);
    }
    
    setState(() => _isLoading = false);
    
    // Focus the editor after a small delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _quillController.dispose();
    _focusNode.dispose();
    _tagController.dispose();
    super.dispose();
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
        // Create new
        await JournalStorageService.createEntry(
          content: content,
          plainText: plainText,
          bucketId: widget.bucketId,
          isPrivate: _isPrivate,
          moodScore: _moodScore,
          tags: _tags,
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
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Add Tag'),
                                  content: TextField(
                                    controller: _tagController,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter tag name',
                                      prefixText: '#',
                                    ),
                                    onSubmitted: (value) {
                                      _addTag(value);
                                      Navigator.pop(ctx);
                                    },
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _addTag(_tagController.text);
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                              );
                            },
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
            
            // Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: QuillEditor(
                  focusNode: _focusNode,
                  scrollController: ScrollController(),
                  configurations: QuillEditorConfigurations(
                    controller: _quillController,
                    placeholder: 'Start writing...',
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            
            // Toolbar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: QuillToolbar.simple(
                configurations: QuillSimpleToolbarConfigurations(
                  controller: _quillController,
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
                  showUndo: true,
                  showRedo: true,
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Avatar overlay with privacy state
      AvatarJournalOverlay(
        isPrivate: _isPrivate,
        archetype: _archetype,
        onSparkTap: () {
          // TODO: Implement AI prompt generation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ Spark: AI prompts coming soon!')),
          );
        },
        onAvatarTap: () {
          // TODO: Expand chat panel
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_archetype[0].toUpperCase()}${_archetype.substring(1)} is ${_isPrivate ? "blind" : "observing"}')),
          );
        },
      ),
    ],
  ),
);
  }
}
