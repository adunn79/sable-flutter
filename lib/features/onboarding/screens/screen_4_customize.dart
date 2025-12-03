import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/core/voice/locale_voice_service.dart';
import 'package:sable/core/voice/voice_service.dart';
import '../models/avatar_config.dart';
import '../services/avatar_generation_service.dart';
import '../services/onboarding_state_service.dart';

class Screen4Customize extends StatefulWidget {
  final String archetype;
  final Function(AvatarConfig, String imageUrl) onComplete;

  const Screen4Customize({
    super.key,
    required this.archetype,
    required this.onComplete,
  });

  @override
  State<Screen4Customize> createState() => _Screen4CustomizeState();
}

class _Screen4CustomizeState extends State<Screen4Customize> {
  OnboardingStateService? _stateService;
  final AvatarGenerationService _avatarService = AvatarGenerationService();
  final VoiceService _voiceService = VoiceService();

  int _apparentAge = 25;
  String _origin = 'United States, California';
  String _race = 'Sable (Synthetic Human)';
  String _build = 'Athletic';
  String _skinTone = 'Golden/Tan';
  String _eyeColor = 'Amber/Honey';
  String _hairStyle = 'Chestnut Waves';
  String _fashionAesthetic = 'Casual (Denim/Comfort)';
  String _distinguishingMark = 'None (Flawless)';
  String? _selectedVoiceId;
  List<dynamic> _availableVoices = []; // Will hold VoiceWithMetadata objects
  bool _isLoadingVoices = false;

  bool _isGenerating = false;
  String? _generatedImageUrl;
  bool? _showCustomization; // null = choice not made, true = customize, false = use as-is

  @override
  void initState() {
    super.initState();
    _initServices();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await _voiceService.initialize();
    await _loadVoicesForOrigin(); // Load initial voices
  }
  
  Future<void> _loadVoicesForOrigin() async {
    setState(() {
      _isLoadingVoices = true;
    });
    
    try {
      final voices = await LocaleVoiceService.getVoicesForOrigin(_origin);
      setState(() {
        _availableVoices = voices;
        _isLoadingVoices = false;
        
        // Clear selected voice if it's not in the new list
        if (_selectedVoiceId != null) {
          final voiceExists = voices.any((v) => v.voiceId == _selectedVoiceId);
          if (!voiceExists) {
            _selectedVoiceId = null;
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading voices: $e');
      setState(() {
        _isLoadingVoices = false;
        _availableVoices = [];
      });
    }
  }

  Future<void> _initServices() async {
    _stateService = await OnboardingStateService.create();
    // Auto-show customization for "Custom" archetype
    if (widget.archetype == 'Custom') {
      _showCustomization = true;
    }
    setState(() {});
  }

  void _handleUseAsIs() {
    // Create default avatar config for the selected archetype
    // Create default avatar config for the selected archetype
    final config = AvatarConfig(
      archetype: widget.archetype,
      gender: _getGender(),
      apparentAge: _apparentAge,
      origin: _origin,
      race: _race,
      build: _build,
      skinTone: _skinTone,
      eyeColor: _eyeColor,
      hairStyle: _hairStyle,
      fashionAesthetic: _fashionAesthetic,
      distinguishingMark: _distinguishingMark,
      selectedVoiceId: _selectedVoiceId,
    );
    
    // Use archetype image as default
    final imageUrl = 'assets/images/archetypes/${widget.archetype.toLowerCase()}.png';
    _stateService?.saveAvatarUrl(imageUrl);
    widget.onComplete(config, imageUrl);
  }

  void _handleCustomize() {
    setState(() {
      _showCustomization = true;
    });
  }

  Future<void> _handleManifest() async {
    if (_stateService == null || !_stateService!.hasGenerationsRemaining) {
      _showUpsellDialog();
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final config = AvatarConfig(
        archetype: widget.archetype,
        gender: _getGender(),
        apparentAge: _apparentAge,
        origin: _origin,
        race: _race,
        build: _build,
        skinTone: _skinTone,
        eyeColor: _eyeColor,
        hairStyle: _hairStyle,
        fashionAesthetic: _fashionAesthetic,
        distinguishingMark: _distinguishingMark,
        selectedVoiceId: _selectedVoiceId,
      );

      final imageUrl = await _avatarService.generateAvatarImage(config);
      await _stateService?.decrementGenerations();

      setState(() {
        _generatedImageUrl = imageUrl;
        _isGenerating = false;
      });

      _showGeneratedAvatar(config, imageUrl);
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate avatar: $e',
                style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGeneratedAvatar(AvatarConfig config, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        title: Text(
          'Your Avatar',
          style: GoogleFonts.spaceGrotesk(
            color: AurealColors.stardust,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              imageUrl,
              height: 300,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Generations remaining: ${_stateService?.remainingGenerations ?? 3}',
              style: GoogleFonts.inter(color: AurealColors.ghost),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Regenerate',
              style: GoogleFonts.inter(color: AurealColors.plasmaCyan),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _stateService?.saveAvatarUrl(imageUrl);
              Navigator.pop(context);
              widget.onComplete(config, imageUrl);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  String _getGender() {
    switch (widget.archetype) {
      case 'Sable':
        return 'Female';
      case 'Kai':
        return 'Male';
      case 'Echo':
        return 'Non-binary';
      case 'Custom':
        // For custom, we default to Female for now as we don't have a selector yet
        // Ideally we should add a gender selector for Custom archetype
        return 'Female';
      default:
        return 'Female';
    }
  }

  void _showUpsellDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        title: Text(
          '⚡ Energy Depleted',
          style: GoogleFonts.spaceGrotesk(
            color: AurealColors.hyperGold,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You\'ve used all 3 free generations. Upgrade to a Spark Pack to continue refining your avatar.',
          style: GoogleFonts.inter(color: AurealColors.stardust),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final config = AvatarConfig(
                archetype: widget.archetype,
                gender: _getGender(),
                apparentAge: _apparentAge,
                origin: _origin,
                race: _race,
                build: _build,
                skinTone: _skinTone,
                eyeColor: _eyeColor,
                hairStyle: _hairStyle,
                fashionAesthetic: _fashionAesthetic,
                distinguishingMark: _distinguishingMark,
                selectedVoiceId: _selectedVoiceId,
              );
              final imageUrl = 'assets/images/archetypes/${widget.archetype.toLowerCase()}.png';
              _stateService?.saveAvatarUrl(imageUrl);
              widget.onComplete(config, imageUrl);
            },
            child: Text(
              'Use Default',
              style: GoogleFonts.inter(color: AurealColors.ghost),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to purchase flow
            },
            child: const Text('Buy Spark Pack'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show choice screen if user hasn't decided and archetype is not Custom
    if (_showCustomization == null) {
      return _buildChoiceScreen();
    }
    
    // Show customization form
    return _buildCustomizationScreen();
  }

  Widget _buildChoiceScreen() {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.archetype.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AurealColors.hyperGold,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(duration: 600.ms),
              
              const SizedBox(height: 16),
              
              Text(
                'How would you like to proceed?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AurealColors.ghost,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms).fadeIn(duration: 600.ms),
              
              const SizedBox(height: 48),
              
              // Use Default Appearance Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleUseAsIs,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'USE ${widget.archetype.toUpperCase()} AS-IS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep the default appearance',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AurealColors.ghost,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 16),
              
              // Customize Appearance Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleCustomize,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    side: const BorderSide(color: AurealColors.plasmaCyan),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'CUSTOMIZE APPEARANCE',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AurealColors.plasmaCyan,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Design your own look',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AurealColors.ghost,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 500.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizationScreen() {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Title
                    Text(
                      widget.archetype == 'Custom' 
                          ? 'CREATE YOUR COMPANION'
                          : 'CUSTOMIZE ${widget.archetype.toUpperCase()}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AurealColors.hyperGold,
                        letterSpacing: 2,
                      ),
                    ).animate().fadeIn(duration: 600.ms),

                    const SizedBox(height: 8),

                    Text(
                      'Generations remaining: ${_stateService?.remainingGenerations ?? 3}/3',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AurealColors.plasmaCyan,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Apparent Age
                    _buildSectionLabel('Apparent Age: $_apparentAge'),
                    Slider(
                      value: _apparentAge.toDouble(),
                      min: 18,
                      max: 65,
                      divisions: 47,
                      activeColor: AurealColors.plasmaCyan,
                      onChanged: (value) {
                        setState(() {
                          _apparentAge = value.toInt();
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    _buildSectionLabel('Origin (Accent)'),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Autocomplete<String>(
                          initialValue: TextEditingValue(text: _origin),
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') {
                              return const Iterable<String>.empty();
                            }
                            return [
                              'United States, California',
                              'United States, New York',
                              'United States, Texas',
                              'United States, Florida',
                              'United Kingdom, London',
                              'United Kingdom, Manchester',
                              'France, Paris',
                              'France, Lyon',
                              'Germany, Berlin',
                              'Germany, Munich',
                              'Japan, Tokyo',
                              'Japan, Osaka',
                              'South Korea, Seoul',
                              'China, Shanghai',
                              'China, Beijing',
                              'Australia, Sydney',
                              'Australia, Melbourne',
                              'Brazil, São Paulo',
                              'Brazil, Rio de Janeiro',
                              'India, Mumbai',
                              'India, Delhi',
                              'Russia, Moscow',
                              'Canada, Toronto',
                              'Canada, Vancouver',
                              'Italy, Rome',
                              'Italy, Milan',
                              'Spain, Madrid',
                              'Spain, Barcelona',
                              'Mexico, Mexico City',
                              'Argentina, Buenos Aires',
                              'South Africa, Cape Town',
                              'Egypt, Cairo',
                              'Turkey, Istanbul',
                              'UAE, Dubai',
                              'Singapore',
                              'Thailand, Bangkok',
                              'Vietnam, Ho Chi Minh City',
                              'Indonesia, Jakarta',
                              'Nigeria, Lagos',
                              'Kenya, Nairobi',
                            ].where((String option) {
                              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            setState(() {
                              _origin = selection;
                            });
                          },
                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                            // Update state when text changes (for custom input)
                            textEditingController.addListener(() {
                              _origin = textEditingController.text;
                            });
                            
                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: GoogleFonts.inter(color: AurealColors.stardust),
                              decoration: InputDecoration(
                                hintText: 'Type a city or country...',
                                hintStyle: GoogleFonts.inter(color: AurealColors.ghost),
                                filled: true,
                                fillColor: AurealColors.carbon,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: const Icon(Icons.search, color: AurealColors.ghost),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                color: AurealColors.carbon,
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height: 200,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final String option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(
                                          option,
                                          style: GoogleFonts.inter(color: AurealColors.stardust),
                                        ),
                                        onTap: () {
                                          onSelected(option);
                                        },
                                        hoverColor: AurealColors.plasmaCyan.withOpacity(0.1),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Voice Selection
                    _buildSectionLabel('Voice (Accent-Based)'),
                    const SizedBox(height: 8),
                    _buildVoiceSelection(),

                    const SizedBox(height: 24),

                    // Race
                    _buildSectionLabel('Race'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _race,
                      items: [
                        'Sable (Synthetic Human)',
                        'Caucasian',
                        'Asian',
                        'Black/African Descent',
                        'Latino/Hispanic',
                        'Middle Eastern',
                        'South Asian',
                        'Pacific Islander',
                        'Indigenous',
                        'Mixed Heritage',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _race = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Build
                    _buildSectionLabel('Build'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _build,
                      items: [
                        'Petite',
                        'Athletic',
                        'Curvy',
                        'Lean/Tall',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _build = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Skin Tone
                    _buildSectionLabel('Skin Tone'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _skinTone,
                      items: [
                        'Porcelain',
                        'Fair (Cool)',
                        'Golden/Tan',
                        'Olive',
                        'Deep Rich',
                        'Synthetic (Glow)',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _skinTone = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Eye Color
                    _buildSectionLabel('Eye Color'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _eyeColor,
                      items: [
                        'Onyx Black',
                        'Steel Grey',
                        'Amber/Honey',
                        'Emerald Green',
                        'Ice Blue',
                        'Violet',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _eyeColor = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Hair Style & Color
                    _buildSectionLabel('Hair Style & Color'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _hairStyle,
                      items: [
                        'Platinum Bob',
                        'Golden Blond',
                        'Jet Black Sleek',
                        'Chestnut Waves',
                        'Silver Pixie',
                        'Auburn Braid',
                        'Neon/Cyber Undercut',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _hairStyle = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Fashion Aesthetic
                    _buildSectionLabel('Fashion Aesthetic'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _fashionAesthetic,
                      items: [
                        'Executive (Suit)',
                        'Casual (Denim/Comfort)',
                        'Evening Gown (Elegant/Alluring)',
                        'Minimalist (Basics)',
                        'Evening (Formal)',
                        'Technical (Sport/Gym)',
                        'Cyber (Futuristic)',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _fashionAesthetic = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    // Distinguishing Mark
                    _buildSectionLabel('Distinguishing Mark'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _distinguishingMark,
                      items: [
                        'None (Flawless)',
                        'Beauty Mark (Mole)',
                        'Small Scar (Eyebrow)',
                        'Freckles',
                        'Nose Piercing',
                        'Circuit Lines (Neck)',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _distinguishingMark = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Manifest Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _handleManifest,
                  child: _isGenerating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AurealColors.obsidian),
                          ),
                        )
                      : const Text('MANIFEST FORM'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AurealColors.stardust,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AurealColors.carbon,
      decoration: const InputDecoration(),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
      style: GoogleFonts.inter(color: AurealColors.stardust),
    );
  }

  Widget _buildVoiceSelection() {
    if (_isLoadingVoices) {
      return const Row(
        children: [
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AurealColors.plasmaCyan),
            ),
          ),
        ],
      );
    }
    
    if (_availableVoices.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'No voices available. Check your connection.',
              style: GoogleFonts.inter(color: AurealColors.ghost),
            ),
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedVoiceId,
            dropdownColor: AurealColors.carbon,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select a voice',
              hintStyle: GoogleFonts.inter(color: AurealColors.ghost),
            ),
            items: _availableVoices.map<DropdownMenuItem<String>>((voice) {
              return DropdownMenuItem(
                value: voice.voiceId,
                child: Text(
                  '${voice.name}${voice.gender != null ? " (${voice.gender})" : ""}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedVoiceId = value;
              });
            },
            style: GoogleFonts.inter(color: AurealColors.stardust),
          ),
        ),
        const SizedBox(width: 12),
        if (_selectedVoiceId != null)
          IconButton(
            icon: const Icon(Icons.play_circle_outline, color: AurealColors.plasmaCyan, size: 32),
            onPressed: () async {
              if (_selectedVoiceId != null) {
                await _voiceService.setVoice(_selectedVoiceId!);
                await _voiceService.speak("Hello, I'm excited to be with you.");
              }
            },
          ),
      ],
    );
  }

}
