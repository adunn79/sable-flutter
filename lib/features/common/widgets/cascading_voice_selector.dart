import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/voice/elevenlabs_api_service.dart';

class CascadingVoiceSelector extends StatefulWidget {
  final List<VoiceWithMetadata> voices;
  final String? selectedVoiceId;
  final Function(String) onVoiceSelected;
  final VoidCallback? onPlayPreview;

  const CascadingVoiceSelector({
    super.key,
    required this.voices,
    required this.selectedVoiceId,
    required this.onVoiceSelected,
    this.onPlayPreview,
  });

  @override
  State<CascadingVoiceSelector> createState() => _CascadingVoiceSelectorState();
}

class _CascadingVoiceSelectorState extends State<CascadingVoiceSelector> {
  String? _selectedCountry;
  String? _selectedRegion; // For USA sub-regions
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
  }

  @override
  void didUpdateWidget(CascadingVoiceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedVoiceId != oldWidget.selectedVoiceId) {
      _initializeSelections();
    }
  }

  void _initializeSelections() {
    if (widget.selectedVoiceId != null) {
      try {
        final voice = widget.voices.firstWhere((v) => v.voiceId == widget.selectedVoiceId);
        final region = voice.labels['region'] ?? 'usa';
        _selectedCountry = _getCountryFromRegion(region);
        _selectedRegion = voice.labels['subregion']; // May be null
        _selectedGender = voice.gender;
      } catch (e) {
        // Voice not found in list, reset or keep defaults
      }
    }
  }

  String _getCountryFromRegion(String region) {
    switch (region.toLowerCase()) {
      case 'usa': return 'United States';
      case 'uk': return 'United Kingdom';
      case 'australia': return 'Australia';
      case 'ireland': return 'Ireland';
      case 'russia': return 'Russia';
      case 'france': return 'France';
      case 'italy': return 'Italy';
      case 'spain': return 'Spain';
      case 'sweden': return 'Sweden';
      default: return 'United States';
    }
  }
  
  String _getRegionFromCountry(String country) {
    switch (country) {
      case 'United States': return 'usa';
      case 'United Kingdom': return 'uk';
      case 'Australia': return 'australia';
      case 'Ireland': return 'ireland';
      case 'Russia': return 'russia';
      case 'France': return 'france';
      case 'Italy': return 'italy';
      case 'Spain': return 'spain';
      case 'Sweden': return 'sweden';
      default: return 'usa';
    }
  }

  List<String> get _availableCountries {
    final regions = widget.voices.map((v) => v.labels['region'] ?? 'usa').toSet();
    return regions.map((r) => _getCountryFromRegion(r)).toSet().toList()..sort();
  }

  List<String> get _availableSubRegions {
    if (_selectedCountry != 'United States') return [];
    // Extract subregions from USA voices
    return widget.voices
        .where((v) => (v.labels['region'] ?? 'usa') == 'usa')
        .map((v) => v.labels['subregion'] as String?)
        .where((s) => s != null)
        .cast<String>()
        .toSet()
        .toList()..sort();
  }

  List<String> get _availableGenders {
    // Extract unique genders from available voices
    final genders = widget.voices
        .map((v) => v.gender?.toLowerCase())
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()..sort();
    return genders;
  }

  List<VoiceWithMetadata> get _filteredVoices {
    final filtered = widget.voices.where((v) {
      final countryMatch = _getCountryFromRegion(v.labels['region'] ?? 'usa') == _selectedCountry;
      if (!countryMatch) return false;

      if (_selectedCountry == 'United States' && _selectedRegion != null && _selectedRegion != 'All') {
        if (v.labels['subregion'] != _selectedRegion) return false;
      }

      if (_selectedGender != null && _selectedGender != 'All') {
        if (v.gender?.toLowerCase() != _selectedGender?.toLowerCase()) return false;
      }

      return true;
    }).toList();
    
    // Deduplicate voices by ID to prevent "2 or more items" assertion error
    final seenIds = <String>{};
    return filtered.where((v) => seenIds.add(v.voiceId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country Selector
        _buildDropdown(
          label: 'Country',
          value: _selectedCountry,
          items: _availableCountries,
          onChanged: (val) {
            setState(() {
              _selectedCountry = val;
              _selectedRegion = null; // Reset subregion
              _selectedGender = null; // Reset gender
            });
          },
        ),
        
        const SizedBox(height: 12),

        // Sub-Region Selector (USA Only)
        if (_selectedCountry == 'United States' && _availableSubRegions.isNotEmpty) ...[
          _buildDropdown(
            label: 'Region',
            value: _selectedRegion,
            items: ['All', ..._availableSubRegions],
            onChanged: (val) {
              setState(() {
                _selectedRegion = val == 'All' ? null : val;
              });
            },
          ),
          const SizedBox(height: 12),
        ],

        // Gender Selector
        _buildDropdown(
          label: 'Gender',
          value: _selectedGender,
          items: ['All', ..._availableGenders],
          onChanged: (val) {
            setState(() {
              _selectedGender = val == 'All' ? null : val;
            });
          },
        ),

        const SizedBox(height: 12),

        // Voice Selector
        Builder(
          builder: (context) {
            final filteredVoices = _filteredVoices;
            final hasSelectedVoice = widget.selectedVoiceId != null && 
                filteredVoices.any((v) => v.voiceId == widget.selectedVoiceId);
            
            return Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: hasSelectedVoice ? widget.selectedVoiceId : null,
                    dropdownColor: AelianaColors.carbon,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Voice',
                      labelStyle: GoogleFonts.inter(color: AelianaColors.ghost),
                      filled: true,
                      fillColor: AelianaColors.carbon,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: filteredVoices.map((voice) {
                      return DropdownMenuItem(
                        value: voice.voiceId,
                        child: Text(
                          voice.name,
                          style: GoogleFonts.inter(color: AelianaColors.stardust),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        widget.onVoiceSelected(val);
                      }
                    },
                  ),
                ),
                if (widget.onPlayPreview != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, color: AelianaColors.plasmaCyan),
                    onPressed: widget.onPlayPreview,
                  ),
                ],
              ],
            );
          }
        ),
        
        if (_filteredVoices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'No voices match filters',
              style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      dropdownColor: AelianaColors.carbon,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AelianaColors.ghost),
        filled: true,
        fillColor: AelianaColors.carbon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item.capitalize(),
            style: GoogleFonts.inter(color: AelianaColors.stardust),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
