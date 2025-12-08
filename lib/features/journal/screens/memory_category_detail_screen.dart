import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/core/memory/unified_memory_service.dart';
import 'package:sable/core/memory/models/extracted_memory.dart';

/// Category detail screen showing all memories in a specific category
/// Allows viewing, editing, and deleting individual memories
class MemoryCategoryDetailScreen extends StatefulWidget {
  final MemoryCategory category;
  final VoidCallback? onMemoriesChanged;

  const MemoryCategoryDetailScreen({
    super.key,
    required this.category,
    this.onMemoriesChanged,
  });

  @override
  State<MemoryCategoryDetailScreen> createState() => _MemoryCategoryDetailScreenState();
}

class _MemoryCategoryDetailScreenState extends State<MemoryCategoryDetailScreen> {
  final UnifiedMemoryService _memoryService = UnifiedMemoryService();
  
  List<ExtractedMemory> _memories = [];
  bool _isLoading = true;
  String _sortBy = 'date'; // 'date', 'importance', 'alphabetical'
  
  @override
  void initState() {
    super.initState();
    _loadMemories();
  }
  
  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    
    await _memoryService.initialize();
    final memories = _memoryService.getMemoriesByCategory(widget.category);
    
    setState(() {
      _memories = memories;
      _sortMemories();
      _isLoading = false;
    });
  }
  
  void _sortMemories() {
    switch (_sortBy) {
      case 'date':
        _memories.sort((a, b) => b.extractedAt.compareTo(a.extractedAt));
        break;
      case 'importance':
        _memories.sort((a, b) => b.importance.compareTo(a.importance));
        break;
      case 'alphabetical':
        _memories.sort((a, b) => a.content.toLowerCase().compareTo(b.content.toLowerCase()));
        break;
    }
  }
  
  Future<void> _deleteMemory(ExtractedMemory memory) async {
    await _memoryService.deleteMemory(memory.id);
    widget.onMemoriesChanged?.call();
    await _loadMemories();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Memory deleted'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AurealColors.hyperGold,
            onPressed: () async {
              // Re-add the memory
              await _memoryService.addMemory(
                content: memory.content,
                category: memory.category,
                tags: memory.tags,
                importance: memory.importance,
              );
              widget.onMemoriesChanged?.call();
              await _loadMemories();
            },
          ),
        ),
      );
    }
  }
  
  Future<void> _editMemory(ExtractedMemory memory) async {
    final contentController = TextEditingController(text: memory.content);
    int importance = memory.importance;
    List<String> tags = List.from(memory.tags);
    final tagController = TextEditingController();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AurealColors.carbon,
          title: Row(
            children: [
              Icon(LucideIcons.edit, color: AurealColors.hyperGold, size: 20),
              const SizedBox(width: 8),
              Text('Edit Memory', style: GoogleFonts.inter(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Memory content...',
                    hintStyle: TextStyle(color: AurealColors.ghost),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AurealColors.ghost.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AurealColors.ghost.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AurealColors.hyperGold),
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Importance
                Text('Importance', style: GoogleFonts.inter(color: AurealColors.ghost, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starValue = i + 1;
                    return GestureDetector(
                      onTap: () => setDialogState(() => importance = starValue),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          starValue <= importance ? LucideIcons.star : Icons.star_border,
                          color: starValue <= importance ? AurealColors.hyperGold : AurealColors.ghost,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                
                // Tags
                Text('Tags', style: GoogleFonts.inter(color: AurealColors.ghost, fontSize: 12)),
                const SizedBox(height: 8),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) => Chip(
                      label: Text(tag, style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                      backgroundColor: AurealColors.hyperGold.withOpacity(0.2),
                      deleteIcon: const Icon(LucideIcons.x, size: 14),
                      deleteIconColor: AurealColors.ghost,
                      onDeleted: () => setDialogState(() => tags.remove(tag)),
                    )).toList(),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tagController,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Add tag...',
                          hintStyle: TextStyle(color: AurealColors.ghost, fontSize: 14),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AurealColors.ghost.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AurealColors.ghost.withOpacity(0.3)),
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty && !tags.contains(value.trim())) {
                            setDialogState(() {
                              tags.add(value.trim());
                              tagController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(LucideIcons.plus, color: AurealColors.hyperGold),
                      onPressed: () {
                        final value = tagController.text;
                        if (value.trim().isNotEmpty && !tags.contains(value.trim())) {
                          setDialogState(() {
                            tags.add(value.trim());
                            tagController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AurealColors.ghost)),
            ),
            TextButton(
              onPressed: () {
                if (contentController.text.trim().isNotEmpty) {
                  Navigator.pop(context, {
                    'content': contentController.text.trim(),
                    'importance': importance,
                    'tags': tags,
                  });
                }
              },
              child: Text('Save', style: TextStyle(color: AurealColors.hyperGold)),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      await _memoryService.updateMemory(
        id: memory.id,
        content: result['content'],
        importance: result['importance'],
        tags: result['tags'],
      );
      widget.onMemoriesChanged?.call();
      await _loadMemories();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Memory updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  Future<void> _clearCategory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        title: Text(
          'Clear ${widget.category.name.toUpperCase()}?',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete all ${_memories.length} memories in this category. This cannot be undone.',
          style: GoogleFonts.inter(color: AurealColors.ghost),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AurealColors.ghost)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _memoryService.bulkDeleteByCategory(widget.category);
      widget.onMemoriesChanged?.call();
      await _loadMemories();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category cleared'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  IconData _getCategoryIcon(MemoryCategory category) {
    switch (category) {
      case MemoryCategory.people: return LucideIcons.users;
      case MemoryCategory.preferences: return LucideIcons.heart;
      case MemoryCategory.dates: return LucideIcons.calendar;
      case MemoryCategory.life: return LucideIcons.home;
      case MemoryCategory.emotional: return LucideIcons.smile;
      case MemoryCategory.goals: return LucideIcons.target;
      case MemoryCategory.misc: return LucideIcons.folder;
    }
  }
  
  Color _getCategoryColor(MemoryCategory category) {
    switch (category) {
      case MemoryCategory.people: return Colors.blue;
      case MemoryCategory.preferences: return Colors.pink;
      case MemoryCategory.dates: return Colors.purple;
      case MemoryCategory.life: return Colors.green;
      case MemoryCategory.emotional: return Colors.orange;
      case MemoryCategory.goals: return AurealColors.hyperGold;
      case MemoryCategory.misc: return AurealColors.ghost;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(widget.category);
    
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(color),
            
            // Sort Options
            _buildSortOptions(),
            
            // Memory List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _memories.isEmpty
                      ? _buildEmptyState(color)
                      : _buildMemoryList(color),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getCategoryIcon(widget.category), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_memories.length} memories',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AurealColors.ghost,
                  ),
                ),
              ],
            ),
          ),
          if (_memories.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(LucideIcons.moreVertical, color: AurealColors.ghost),
              color: AurealColors.carbon,
              onSelected: (value) {
                if (value == 'clear') {
                  _clearCategory();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                      const SizedBox(width: 12),
                      Text('Clear All', style: GoogleFonts.inter(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  Widget _buildSortOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AurealColors.ghost,
            ),
          ),
          const SizedBox(width: 12),
          _buildSortChip('Date', 'date'),
          const SizedBox(width: 8),
          _buildSortChip('Importance', 'importance'),
          const SizedBox(width: 8),
          _buildSortChip('A-Z', 'alphabetical'),
        ],
      ),
    );
  }
  
  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
          _sortMemories();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AurealColors.hyperGold.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AurealColors.hyperGold : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isSelected ? AurealColors.hyperGold : AurealColors.ghost,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getCategoryIcon(widget.category), size: 64, color: color.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No memories yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: AurealColors.ghost,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Memories will appear here as I learn about you',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AurealColors.ghost.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMemoryList(Color color) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _memories.length,
      itemBuilder: (context, index) {
        final memory = _memories[index];
        return _buildMemoryCard(memory, color);
      },
    );
  }
  
  Widget _buildMemoryCard(ExtractedMemory memory, Color color) {
    return Dismissible(
      key: Key(memory.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.red),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AurealColors.carbon,
            title: Text('Delete this memory?', style: GoogleFonts.inter(color: Colors.white)),
            content: Text(
              memory.content,
              style: GoogleFonts.inter(color: AurealColors.ghost),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: AurealColors.ghost)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteMemory(memory),
      child: GestureDetector(
        onLongPress: () => _editMemory(memory),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AurealColors.carbon,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      memory.content,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Importance stars
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) => 
                          Icon(
                            i < memory.importance ? LucideIcons.star : Icons.star_border,
                            size: 12,
                            color: i < memory.importance ? AurealColors.hyperGold : AurealColors.ghost.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Tags
                  if (memory.tags.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: memory.tags.take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: color,
                            ),
                          ),
                        )).toList(),
                      ),
                    )
                  else
                    const Spacer(),
                  
                  // Date
                  Text(
                    DateFormat('MMM d, yyyy').format(memory.extractedAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AurealColors.ghost,
                    ),
                  ),
                ],
              ),
              
              // Edit hint
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(LucideIcons.info, size: 10, color: AurealColors.ghost.withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Text(
                    'Long press to edit',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AurealColors.ghost.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
