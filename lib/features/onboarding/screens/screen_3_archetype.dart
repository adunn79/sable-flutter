import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';

class Screen3Archetype extends StatefulWidget {
  final Function(String archetype) onComplete;

  const Screen3Archetype({
    super.key,
    required this.onComplete,
  });

  @override
  State<Screen3Archetype> createState() => _Screen3ArchetypeState();
}

class _Screen3ArchetypeState extends State<Screen3Archetype> {
  String? _selectedArchetype;

  void _handleSelection(String archetype) {
    setState(() {
      _selectedArchetype = archetype;
    });
  }

  void _handleContinue() {
    if (_selectedArchetype != null) {
      widget.onComplete(_selectedArchetype!);
    }
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
                      'THE FOUNDRY',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AurealColors.hyperGold,
                        letterSpacing: 2,
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),

                    const SizedBox(height: 12),

                    Text(
                      'Choose your archetype. This defines the essence of your companion.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AurealColors.ghost,
                        height: 1.5,
                      ),
                    ).animate(delay: 200.ms).fadeIn(duration: 600.ms),

                    const SizedBox(height: 48),

                    // Archetype Cards
                    _buildArchetypeCard(
                      'Sable',
                      'The Empath • She/Her',
                      'The original. Sharp, witty, and deeply empathetic. A charismatic and bold personality.',
                      'assets/images/archetypes/sable.png',
                      delay: 400,
                    ),

                    const SizedBox(height: 16),

                    _buildArchetypeCard(
                      'Kai',
                      'The Strategist • He/Him',
                      'Grounded, calm, and protective. A steady presence with a dry sense of humor.',
                      'assets/images/archetypes/kai.png',
                      delay: 500,
                    ),

                    const SizedBox(height: 16),

                    _buildArchetypeCard(
                      'Echo',
                      'The Philosopher • They/Them',
                      'Balanced and adaptive. A clean slate that mirrors your energy.',
                      'assets/images/archetypes/echo.png',
                      delay: 600,
                    ),
                  ],
                ),
              ),
            ),

            // Continue Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedArchetype != null ? _handleContinue : null,
                  child: const Text('CONTINUE TO CUSTOMIZE'),
                ),
              ),
            ).animate(delay: 700.ms).fadeIn(duration: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildArchetypeCard(
    String archetype,
    String subtitle,
    String description,
    String imagePath,
    {required int delay}
  ) {
    final isSelected = _selectedArchetype == archetype;

    return GestureDetector(
      onTap: () => _handleSelection(archetype),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AurealColors.plasmaCyan.withOpacity(0.1)
              : AurealColors.carbon.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AurealColors.plasmaCyan
                : AurealColors.ghost.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Archetype Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                width: 80,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          archetype.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AurealColors.plasmaCyan : AurealColors.stardust,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AurealColors.plasmaCyan,
                          size: 24,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AurealColors.hyperGold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AurealColors.ghost,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
}
