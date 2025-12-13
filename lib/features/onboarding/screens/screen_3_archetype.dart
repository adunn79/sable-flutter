import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

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
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(
                  physics: const _HighFrictionScrollPhysics(),
                ),
                child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Title
                    Center(
                      child: Text(
                        'THE FOUNDRY',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AelianaColors.hyperGold,
                          letterSpacing: 2,
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),

                    const SizedBox(height: 12),

                    Text(
                      'Choose your archetype. This defines the essence of your companion.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AelianaColors.ghost,
                        height: 1.5,
                      ),
                    ).animate(delay: 200.ms).fadeIn(duration: 600.ms),

                    const SizedBox(height: 8),

                    // Note about customization
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AelianaColors.plasmaCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AelianaColors.plasmaCyan.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AelianaColors.plasmaCyan,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You can customize Race, Gender, and Appearance for any archetype on the next screen.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AelianaColors.plasmaCyan,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 300.ms).fadeIn(duration: 600.ms),

                    const SizedBox(height: 32),

                    // Archetype Cards
                    
                    // AELIANA - The flagship archetype
                    _buildArchetypeCard(
                      'Aeliana',
                      'The Solar Radiance • She/Her',
                      'Ay-lee-AH-na. "Of the Sun." Warm, luminous, and genuinely alive. Living technology with a digital soul.',
                      'assets/images/archetypes/aeliana.png',
                      delay: 350,
                    ),

                    const SizedBox(height: 16),

                    // IMANI - African American female archetype
                    _buildArchetypeCard(
                      'Imani',
                      'The Ancestress • She/Her',
                      'ee-MAH-nee. "Faith." Grounded in ancestral wisdom, radiating divine Black girl magic.',
                      'assets/images/archetypes/imani.png',
                      delay: 375,
                    ),

                    const SizedBox(height: 16),

                    // PRIYA - Indian female archetype
                    _buildArchetypeCard(
                      'Priya',
                      'The Guru • She/Her',
                      'PREE-yah. "Beloved." Serene wisdom rooted in ancient Sanskrit traditions.',
                      'assets/images/archetypes/priya.png',
                      delay: 385,
                    ),

                    const SizedBox(height: 16),

                    _buildArchetypeCard(
                      'Sable',
                      'The Empath • She/Her',
                      'SAY-bull. The original. Sharp, witty, and deeply empathetic. A charismatic personality.',
                      'assets/images/archetypes/sable.png',
                      delay: 400,
                    ),

                    const SizedBox(height: 16),

                    _buildArchetypeCard(
                      'Echo',
                      'The Philosopher • They/Them',
                      'EH-koh. Balanced and adaptive. A clean slate that mirrors your energy.',
                      'assets/images/archetypes/echo.png',
                      delay: 450,
                    ),

                    const SizedBox(height: 16),

                    _buildArchetypeCard(
                      'Kai',
                      'The Strategist • He/Him',
                      'KY. Grounded, calm, and protective. A steady presence with a dry sense of humor.',
                      'assets/images/archetypes/kai.png',
                      delay: 500,
                    ),

                    const SizedBox(height: 16),

                    _buildArchetypeCard(
                      'Marco',
                      'The Guardian • He/Him',
                      'MAR-koh. Warm, passionate, and fiercely loyal. Treats you like familia from day one.',
                      'assets/images/archetypes/marco.png',
                      delay: 550,
                    ),

                    const SizedBox(height: 16),

                    // ARJUN - Indian male strategist
                    _buildArchetypeCard(
                      'Arjun',
                      'The Strategist • He/Him',
                      'ar-JOON. Sharp, analytical, and driven. A brilliant tech founder who sees three moves ahead.',
                      'assets/images/archetypes/arjun.png',
                      delay: 575,
                    ),

                    const SizedBox(height: 16),

                    // RAVI - Indian male spiritual guide
                    _buildArchetypeCard(
                      'Ravi',
                      'The Guide • He/Him',
                      'RAH-vee. Warm, nurturing wisdom. Draws from Vedantic philosophy and ancient stories.',
                      'assets/images/archetypes/ravi.png',
                      delay: 590,
                    ),

                    const SizedBox(height: 16),

                    // JAMES - British gentleman
                    _buildArchetypeCard(
                      'James',
                      'The Gentleman • He/Him',
                      'JAYMS. Refined British charm, dry wit, quietly romantic. Think Oxford don meets 007.',
                      'assets/images/archetypes/james.png',
                      delay: 605,
                    ),

                    const SizedBox(height: 16),

                    _buildArchetypeCard(
                      'Custom',
                      'Your Vision • Your Choice',
                      'Start from scratch and build your ideal companion from the ground up.',
                      null, // No image for custom
                      delay: 650,
                    ),


                    const SizedBox(height: 24),

                    Text(
                      'Note: You will have the option to keep these looks or regenerate new ones.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AelianaColors.ghost,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: 800.ms).fadeIn(duration: 600.ms),
                  ],
                ),
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
    String? imagePath,
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
              ? AelianaColors.plasmaCyan.withOpacity(0.1)
              : AelianaColors.carbon.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AelianaColors.plasmaCyan
                : AelianaColors.ghost.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Archetype Image or Icon
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AelianaColors.hyperGold.withOpacity(0.3),
                      AelianaColors.plasmaCyan.withOpacity(0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: AelianaColors.stardust,
                  size: 40,
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
                            color: isSelected ? AelianaColors.plasmaCyan : AelianaColors.stardust,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AelianaColors.plasmaCyan,
                          size: 24,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AelianaColors.hyperGold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AelianaColors.ghost,
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

/// Custom scroll physics with high friction for deliberate, controlled scrolling
class _HighFrictionScrollPhysics extends ScrollPhysics {
  const _HighFrictionScrollPhysics({super.parent});

  @override
  _HighFrictionScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _HighFrictionScrollPhysics(parent: buildParent(ancestor));
  }

  /// Much higher friction = slower scroll deceleration
  @override
  double get dragStartDistanceMotionThreshold => 18.0; // Default is ~3.5

  /// Reduce velocity significantly on fling
  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Reduce velocity by 80% for much slower scrolling
    final reducedVelocity = velocity * 0.2;
    
    // Use clamping behavior (no overscroll bounce)
    if ((velocity > 0.0 && position.pixels >= position.maxScrollExtent) ||
        (velocity < 0.0 && position.pixels <= position.minScrollExtent)) {
      return null; // Stop at bounds
    }
    
    // Create friction simulation with very high friction
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: reducedVelocity,
      friction: 0.015, // Much lower = more friction (default is ~0.135)
    );
  }
}
