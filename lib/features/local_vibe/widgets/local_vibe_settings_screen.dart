import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/features/local_vibe/models/local_vibe_settings.dart';
import 'package:sable/features/local_vibe/services/local_vibe_service.dart';

class LocalVibeSettingsScreen extends StatefulWidget {
  final LocalVibeService service;

  const LocalVibeSettingsScreen({super.key, required this.service});

  @override
  State<LocalVibeSettingsScreen> createState() => _LocalVibeSettingsScreenState();
}

class _LocalVibeSettingsScreenState extends State<LocalVibeSettingsScreen> {
  late LocalVibeSettings _settings;
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  final List<String> _suggestedCategories = [
    '🍽️ New Openings',
    '🚧 Traffic Alerts',
    '⚠️ Safety Watch',
    '🥦 Farmer\'s Markets',
    '🏫 Town Hall',
    '🎨 Art Galleries',
    '⚽ Local Sports',
    '🏡 Real Estate',
    '🏢 Apartments for Rent',
  ];

  @override
  void initState() {
    super.initState();
    _settings = widget.service.settings;
  }

  void _save() {
    widget.service.updateSettings(_settings);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: AelianaColors.obsidian,
        elevation: 0,
        title: Text(
          'LOCAL VIBE SETTINGS',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('SAVE', style: GoogleFonts.inter(color: AelianaColors.plasmaCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('LOCATION MODE'),
            const SizedBox(height: 16),
            _buildLocationToggle(),
            
            if (_settings.useCurrentLocation)
              _buildRadiusSlider()
            else
              _buildCityInput(),
            
            const SizedBox(height: 32),
            _buildSectionHeader('CATEGORIES'),
            const SizedBox(height: 8),
            Text(
              'Select what you want to track locally.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildCategoryChips(),
            
            const SizedBox(height: 24),
            _buildCustomCategoryInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        color: AelianaColors.plasmaCyan,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildLocationToggle() {
    return Row(
      children: [
        Expanded(
          child: _buildSegmentButton(
            'Current Location',
            _settings.useCurrentLocation,
            () {
              setState(() => _settings = _settings.copyWith(useCurrentLocation: true));
              widget.service.updateSettings(_settings);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSegmentButton(
            'Specific Cities',
            !_settings.useCurrentLocation,
            () {
              setState(() => _settings = _settings.copyWith(useCurrentLocation: false));
              widget.service.updateSettings(_settings);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AelianaColors.hyperGold.withOpacity(0.2) : AelianaColors.carbon,
          border: Border.all(
            color: isSelected ? AelianaColors.hyperGold : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: isSelected ? AelianaColors.hyperGold : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRadiusSlider() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AelianaColors.carbon,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Search Radius', style: GoogleFonts.inter(color: Colors.white70)),
                Text(
                  '${_settings.radiusMiles.toInt()} miles',
                  style: GoogleFonts.inter(color: AelianaColors.plasmaCyan, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AelianaColors.plasmaCyan,
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                overlayColor: AelianaColors.plasmaCyan.withOpacity(0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _settings.radiusMiles,
                min: 1,
                max: 50,
                divisions: 49,
                onChanged: (val) {
                  setState(() => _settings = _settings.copyWith(radiusMiles: val));
                  widget.service.updateSettings(_settings);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_settings.targetCities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _settings.targetCities.map((city) => Chip(
                  label: Text(city, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  backgroundColor: AelianaColors.plasmaCyan.withOpacity(0.2),
                  deleteIcon: const Icon(LucideIcons.x, size: 14, color: AelianaColors.plasmaCyan),
                  onDeleted: () {
                    final updated = List<String>.from(_settings.targetCities)..remove(city);
                    setState(() => _settings = _settings.copyWith(targetCities: updated));
                    widget.service.updateSettings(_settings);
                  },
                  side: const BorderSide(color: AelianaColors.plasmaCyan),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                )).toList(),
              ),
            ),
          if (_settings.targetCities.length < 5)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AelianaColors.carbon,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _cityController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add city (e.g. Brooklyn, NY)',
                        hintStyle: GoogleFonts.inter(color: Colors.white30),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _addCity(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(LucideIcons.plusCircle, color: AelianaColors.plasmaCyan),
                  onPressed: _addCity,
                  style: IconButton.styleFrom(
                    backgroundColor: AelianaColors.carbon,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _addCity() {
    final city = _cityController.text.trim();
    if (city.isNotEmpty && !_settings.targetCities.contains(city)) {
      final updated = List<String>.from(_settings.targetCities)..add(city);
      setState(() {
        _settings = _settings.copyWith(targetCities: updated);
        _cityController.clear();
      });
      widget.service.updateSettings(_settings);
    }
  }

  Widget _buildCategoryChips() {
    final allCategories = {
      ..._settings.activeCategories,
      ..._suggestedCategories,
    }.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allCategories.map((category) {
        final isSelected = _settings.activeCategories.contains(category);
        return _buildCategoryChip(
          category,
          isSelected,
          () {
            final updated = List<String>.from(_settings.activeCategories);
            if (isSelected) {
              updated.remove(category);
            } else {
              updated.add(category);
            }
            setState(() => _settings = _settings.copyWith(activeCategories: updated));
            widget.service.updateSettings(_settings);
          },
        );
      }).toList(),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AelianaColors.plasmaCyan.withOpacity(0.2) : AelianaColors.carbon,
          border: Border.all(
            color: isSelected ? AelianaColors.plasmaCyan : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? AelianaColors.plasmaCyan : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCategoryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom Categories (${_settings.customCategories.length}/5)', style: GoogleFonts.inter(color: Colors.white70)),
        const SizedBox(height: 12),
        if (_settings.customCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _settings.customCategories.map((cat) => Chip(
                label: Text(cat, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                backgroundColor: AelianaColors.plasmaCyan.withOpacity(0.2),
                deleteIcon: const Icon(LucideIcons.x, size: 14, color: AelianaColors.plasmaCyan),
                onDeleted: () {
                  final updated = List<String>.from(_settings.customCategories)..remove(cat);
                  setState(() => _settings = _settings.copyWith(customCategories: updated));
                  widget.service.updateSettings(_settings);
                },
                side: const BorderSide(color: AelianaColors.plasmaCyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              )).toList(),
            ),
          ),
        if (_settings.customCategories.length < 5)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AelianaColors.carbon,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _categoryController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add custom (e.g. Jazz Clubs)',
                      hintStyle: GoogleFonts.inter(color: Colors.white30),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _addCustomCategory(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.plusCircle, color: AelianaColors.plasmaCyan),
                onPressed: _addCustomCategory,
                style: IconButton.styleFrom(
                  backgroundColor: AelianaColors.carbon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _addCustomCategory() {
    final cat = _categoryController.text.trim();
    if (cat.isNotEmpty && !_settings.customCategories.contains(cat)) {
      final updated = List<String>.from(_settings.customCategories)..add(cat);
      setState(() {
        _settings = _settings.copyWith(customCategories: updated);
        _categoryController.clear();
      });
      widget.service.updateSettings(_settings);
    }
  }
}
