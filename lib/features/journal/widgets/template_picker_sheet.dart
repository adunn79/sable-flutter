import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/journal_template.dart';

/// Beautiful bottom sheet for selecting journal templates
class TemplatePickerSheet extends StatefulWidget {
  final Function(JournalTemplate) onTemplateSelected;

  const TemplatePickerSheet({
    super.key,
    required this.onTemplateSelected,
  });

  @override
  State<TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<TemplatePickerSheet> {
  String? _selectedCategory;

  List<JournalTemplate> get _filteredTemplates {
    if (_selectedCategory == null) {
      return JournalTemplates.all;
    }
    return JournalTemplates.getByCategory(_selectedCategory!);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...JournalTemplates.categories];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                const Icon(LucideIcons.layoutTemplate, color: Color(0xFF5DD9C1), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Choose a Template',
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

          // Category chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: categories.map((category) {
                final isSelected = category == 'All' 
                    ? _selectedCategory == null 
                    : _selectedCategory == category;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category == 'All' ? null : category;
                      });
                    },
                    backgroundColor: const Color(0xFF0D1B2A),
                    selectedColor: const Color(0xFF5DD9C1).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF5DD9C1) : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF5DD9C1) : Colors.white24,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Template grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredTemplates.length,
              itemBuilder: (context, index) {
                final template = _filteredTemplates[index];
                return _buildTemplateCard(template);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(JournalTemplate template) {
    Color cardColor;
    switch (template.category) {
      case 'Reflection':
        cardColor = const Color(0xFFB8A9D9); // Lavender
        break;
      case 'Health':
      case 'Wellness':
        cardColor = const Color(0xFF5DD9C1); // Teal
        break;
      case 'Work':
        cardColor = Colors.orange;
        break;
      case 'Growth':
        cardColor = Colors.amber;
        break;
      case 'Personal':
        cardColor = Colors.pink;
        break;
      default:
        cardColor = Colors.cyan;
    }

    return GestureDetector(
      onTap: () {
        widget.onTemplateSelected(template);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cardColor.withOpacity(0.15),
              cardColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardColor.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji and category badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  template.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    template.category,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: cardColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Template name
            Text(
              template.name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            
            // Description
            Expanded(
              child: Text(
                template.description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white60,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Field count
            Row(
              children: [
                Icon(LucideIcons.list, size: 12, color: cardColor),
                const SizedBox(width: 4),
                Text(
                  '${template.fields.length} ${template.fields.length == 1 ? 'field' : 'fields'}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
