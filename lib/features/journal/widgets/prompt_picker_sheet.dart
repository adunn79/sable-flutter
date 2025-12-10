import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/journal_prompts.dart';

/// Beautiful prompt picker for journaling inspiration
class PromptPickerSheet extends StatefulWidget {
  final Function(String) onPromptSelected;

  const PromptPickerSheet({
    super.key,
    required this.onPromptSelected,
  });

  @override
  State<PromptPickerSheet> createState() => _PromptPickerSheetState();
}

class _PromptPickerSheetState extends State<PromptPickerSheet> {
  String _selectedCategory = 'Contextual';
  late String _currentPrompt;

  @override
  void initState() {
    super.initState();
    _currentPrompt = JournalPrompts.getContextualPrompt();
  }

  void _refreshPrompt() {
    setState(() {
      _currentPrompt = _selectedCategory == 'Contextual'
          ? JournalPrompts.getContextualPrompt()
          : JournalPrompts.getPrompt(_selectedCategory);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2D3D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(LucideIcons.sparkles, color: Color(0xFFB8A9D9), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Writing Prompt',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Category pills
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: JournalPrompts.allCategories.map((category) {
                final isSelected = category == _selectedCategory;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                      _refreshPrompt();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFFB8A9D9).withOpacity(0.2)
                            : const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFFB8A9D9) 
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected 
                              ? const Color(0xFFB8A9D9) 
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // Prompt card
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large quote icon
                    const Icon(
                      LucideIcons.quote,
                      size: 48,
                      color: Color(0xFFB8A9D9),
                    ),
                    const SizedBox(height: 24),
                    
                    // Prompt text
                    Text(
                      _currentPrompt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Shuffle button
                        OutlinedButton.icon(
                          onPressed: _refreshPrompt,
                          icon: const Icon(LucideIcons.shuffle, size: 18),
                          label: const Text('New Prompt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Use button
                        ElevatedButton.icon(
                          onPressed: () {
                            widget.onPromptSelected(_currentPrompt);
                            Navigator.pop(context);
                          },
                          icon: const Icon(LucideIcons.check, size: 18),
                          label: const Text('Use This'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB8A9D9),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
