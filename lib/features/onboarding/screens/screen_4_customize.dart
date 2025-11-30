import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';
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

  int _apparentAge = 25;
  String _origin = 'United States, California';
  String _build = 'Athletic';
  String _skinTone = 'Golden/Tan';
  String _eyeColor = 'Amber/Honey';
  String _hairStyle = 'Chestnut Waves';
  String _fashionAesthetic = 'Casual (Denim/Comfort)';
  String _distinguishingMark = 'None (Flawless)';

  bool _isGenerating = false;
  String? _generatedImageUrl;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    _stateService = await OnboardingStateService.create();
    setState(() {});
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
        apparentAge: _apparentAge,
        origin: _origin,
        build: _build,
        skinTone: _skinTone,
        eyeColor: _eyeColor,
        hairStyle: _hairStyle,
        fashionAesthetic: _fashionAesthetic,
        distinguishingMark: _distinguishingMark,
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
              Navigator.pop(context);
              widget.onComplete(config, imageUrl);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
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
                apparentAge: _apparentAge,
                origin: _origin,
                build: _build,
                skinTone: _skinTone,
                eyeColor: _eyeColor,
                hairStyle: _hairStyle,
                fashionAesthetic: _fashionAesthetic,
                distinguishingMark: _distinguishingMark,
              );
              widget.onComplete(config, '');
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
                      'CUSTOMIZE ${widget.archetype.toUpperCase()}',
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

                    // Origin
                    _buildSectionLabel('Origin (Accent)'),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: _origin,
                      items: [
                        'United States, California',
                        'United States, New York',
                        'United Kingdom, London',
                        'France, Paris',
                        'Japan, Tokyo',
                        'Australia, Sydney',
                        'Brazil, São Paulo',
                        'India, Mumbai',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _origin = value;
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
}
