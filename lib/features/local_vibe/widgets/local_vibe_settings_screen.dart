import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aureal_theme.dart';
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
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Local Vibe Settings', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('SAVE', style: GoogleFonts.inter(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('LOCATION'),
            _buildLocationToggle(),
            if (_settings.useCurrentLocation)
              _buildRadiusSlider()
            else
              _buildCityInput(),
            
            const SizedBox(height: 32),
            _buildSectionHeader('CATEGORIES'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: AurealColors.plasmaCyan,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildLocationToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<bool>(
            value: true,
            groupValue: _settings.useCurrentLocation,
            onChanged: (val) => setState(() => _settings = _settings.copyWith(useCurrentLocation: true)),
            title: Text('Current Location (GPS)', style: GoogleFonts.inter(color: Colors.white)),
            secondary: const Icon(LucideIcons.mapPin, color: AurealColors.hyperGold),
            activeColor: AurealColors.plasmaCyan,
          ),
          RadioListTile<bool>(
            value: false,
            groupValue: _settings.useCurrentLocation,
            onChanged: (val) => setState(() => _settings = _settings.copyWith(useCurrentLocation: false)),
            title: Text('Specific Cities', style: GoogleFonts.inter(color: Colors.white)),
            secondary: const Icon(LucideIcons.building, color: Colors.white54),
            activeColor: AurealColors.plasmaCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSlider() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Search Radius', style: GoogleFonts.inter(color: Colors.white70)),
              Text('${_settings.radiusMiles.toInt()} miles', style: GoogleFonts.inter(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _settings.radiusMiles,
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: AurealColors.plasmaCyan,
            inactiveColor: Colors.white10,
            onChanged: (val) => setState(() => _settings = _settings.copyWith(radiusMiles: val)),
          ),
        ],
      ),
    );
  }

  Widget _buildCityInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _settings.targetCities.map((city) => Chip(
              label: Text(city, style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: AurealColors.carbon,
              deleteIcon: const Icon(LucideIcons.x, size: 14, color: Colors.white54),
              onDeleted: () {
                final updated = List<String>.from(_settings.targetCities)..remove(city);
                setState(() => _settings = _settings.copyWith(targetCities: updated));
              },
            )).toList(),
          ),
          const SizedBox(height: 12),
          if (_settings.targetCities.length < 5)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add city (e.g. Brooklyn, NY)',
                      hintStyle: GoogleFonts.inter(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _addCity(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(LucideIcons.plusCircle, color: AurealColors.plasmaCyan),
                  onPressed: _addCity,
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
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (selected) {
            final updated = List<String>.from(_settings.activeCategories);
            if (selected) {
              updated.add(category);
            } else {
              updated.remove(category);
            }
            setState(() => _settings = _settings.copyWith(activeCategories: updated));
          },
          backgroundColor: Colors.white.withOpacity(0.05),
          selectedColor: AurealColors.plasmaCyan.withOpacity(0.2),
          checkmarkColor: AurealColors.plasmaCyan,
          labelStyle: GoogleFonts.inter(
            color: isSelected ? AurealColors.plasmaCyan : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? AurealColors.plasmaCyan.withOpacity(0.5) : Colors.white10,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomCategoryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom Categories (${_settings.customCategories.length}/5)', style: GoogleFonts.inter(color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _settings.customCategories.map((cat) => Chip(
            label: Text(cat, style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: AurealColors.carbon,
            deleteIcon: const Icon(LucideIcons.x, size: 14, color: Colors.white54),
            onDeleted: () {
              final updated = List<String>.from(_settings.customCategories)..remove(cat);
              setState(() => _settings = _settings.copyWith(customCategories: updated));
            },
          )).toList(),
        ),
        const SizedBox(height: 12),
        if (_settings.customCategories.length < 5)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _categoryController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add custom (e.g. Jazz Clubs)',
                    hintStyle: GoogleFonts.inter(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _addCustomCategory(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.plusCircle, color: AurealColors.plasmaCyan),
                onPressed: _addCustomCategory,
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
    }
  }
}
