import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/aeliana_theme.dart';
import '../models/private_user_persona.dart';

/// Editor widget for creating/editing user persona in Private Space
class PrivatePersonaEditor extends StatefulWidget {
  final PrivateUserPersona? existingPersona;
  final Function(PrivateUserPersona) onSave;

  const PrivatePersonaEditor({
    super.key,
    this.existingPersona,
    required this.onSave,
  });

  @override
  State<PrivatePersonaEditor> createState() => _PrivatePersonaEditorState();
}

class _PrivatePersonaEditorState extends State<PrivatePersonaEditor> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _backgroundController = TextEditingController();
  String? _selectedGender;

  final List<String> _genderOptions = [
    'Female',
    'Male', 
    'Non-binary',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingPersona != null) {
      _nameController.text = widget.existingPersona!.aliasName;
      _ageController.text = widget.existingPersona!.aliasAge?.toString() ?? '';
      _selectedGender = widget.existingPersona!.aliasGender;
      _descriptionController.text = widget.existingPersona!.aliasDescription ?? '';
      _backgroundController.text = widget.existingPersona!.aliasBackground ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _descriptionController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a name for your persona'),
          backgroundColor: Colors.red.withOpacity(0.8),
        ),
      );
      return;
    }

    final persona = PrivateUserPersona.create(
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text),
      gender: _selectedGender,
      description: _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : null,
      background: _backgroundController.text.trim().isNotEmpty 
          ? _backgroundController.text.trim() 
          : null,
    );

    widget.onSave(persona);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AelianaColors.plasmaCyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(LucideIcons.userCog, color: AelianaColors.hyperGold, size: 24),
              const SizedBox(width: 12),
              Text(
                widget.existingPersona != null ? 'Edit Persona' : 'Create Persona',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Create an alternate identity for Private Space roleplay',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          _buildTextField(
            controller: _nameController,
            label: 'Alias Name',
            hint: 'What should they call you?',
            icon: LucideIcons.user,
          ),
          const SizedBox(height: 16),

          // Age and Gender row
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  hint: '25',
                  icon: LucideIcons.calendar,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  label: 'Gender',
                  value: _selectedGender,
                  options: _genderOptions,
                  onChanged: (v) => setState(() => _selectedGender = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          _buildTextField(
            controller: _descriptionController,
            label: 'Brief Description',
            hint: 'A mysterious traveler with a secret past...',
            icon: LucideIcons.penTool,
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Background/Backstory
          _buildTextField(
            controller: _backgroundController,
            label: 'Background Story (optional)',
            hint: 'I grew up in a coastal town where legends spoke of...',
            icon: LucideIcons.bookOpen,
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AelianaColors.hyperGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save Persona',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(icon, color: AelianaColors.plasmaCyan, size: 20),
            filled: true,
            fillColor: AelianaColors.obsidian,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AelianaColors.plasmaCyan.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AelianaColors.plasmaCyan.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AelianaColors.hyperGold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AelianaColors.obsidian,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AelianaColors.plasmaCyan.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                'Select',
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.3)),
              ),
              isExpanded: true,
              dropdownColor: AelianaColors.carbon,
              style: GoogleFonts.inter(color: Colors.white),
              items: options.map((opt) => DropdownMenuItem(
                value: opt.toLowerCase(),
                child: Text(opt),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
