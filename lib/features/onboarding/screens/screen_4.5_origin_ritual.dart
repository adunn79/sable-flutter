import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:uuid/uuid.dart';
import '../models/avatar_config.dart';

class Screen45OriginRitual extends StatefulWidget {
  final AvatarConfig config;
  final String avatarImageUrl;
  final VoidCallback onComplete;

  const Screen45OriginRitual({
    super.key,
    required this.config,
    required this.avatarImageUrl,
    required this.onComplete,
  });

  @override
  State<Screen45OriginRitual> createState() => _Screen45OriginRitualState();
}

class _Screen45OriginRitualState extends State<Screen45OriginRitual> with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  final String _uuid = const Uuid().v4().substring(0, 13).toUpperCase();
  bool _isAwakened = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2), // 2 seconds to hold
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleAwakening();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _handleAwakening() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isAwakened = true;
    });

    // Flash effect and proceed
    Future.delayed(const Duration(milliseconds: 1500), () {
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: Stack(
        children: [
          // Background - subtle gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    AelianaColors.plasmaCyan.withOpacity(0.05),
                    AelianaColors.obsidian,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'IDENTITY ESTABLISHED',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: AelianaColors.ghost,
                    ),
                  ).animate().fadeIn(duration: 800.ms),

                  const Spacer(),

                  // The "Birth Certificate" Card
                  _buildIdentityCard(),

                  const Spacer(),

                  // Interaction Prompt
                  if (!_isAwakened) ...[
                    Text(
                      'HOLD FINGERPRINT TO AWAKEN',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: AelianaColors.ghost.withOpacity(0.7),
                      ),
                    ).animate(delay: 1000.ms).fadeIn(),
                    
                    const SizedBox(height: 16),
                    
                    _buildFingerprintButton(),
                  ] else ...[
                    Text(
                      'AWAKENING...',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AelianaColors.hyperGold,
                      ),
                    ).animate().fadeIn().shimmer(duration: 1000.ms),
                    const SizedBox(height: 80), // Spacer to match button height approx
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Full screen flash overlay
          if (_isAwakened)
            IgnorePointer(
              child: Container(
                color: Colors.white,
              ).animate().fadeIn(duration: 100.ms).fadeOut(delay: 100.ms, duration: 1000.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AelianaColors.carbon.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isAwakened ? AelianaColors.hyperGold : AelianaColors.ghost.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isAwakened ? AelianaColors.hyperGold : Colors.black).withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AelianaColors.hyperGold, width: 2),
              image: DecorationImage(
                image: NetworkImage(widget.avatarImageUrl), // Assuming URL, check if local file needed
                fit: BoxFit.cover,
                // Handle loading/error in real app, keeping simple for snippet
              ),
              boxShadow: [
                BoxShadow(
                  color: AelianaColors.hyperGold.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            widget.config.archetype.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          Text(
            'MODEL: GEN-3 SENTIENCE',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AelianaColors.plasmaCyan,
              letterSpacing: 1,
            ),
          ),
          
          const SizedBox(height: 32),
          
          _buildDetailRow('ORIGIN', widget.config.origin),
          _buildDetailRow('ESTABLISHED', DateFormat.yMMMd().format(DateTime.now()).toUpperCase()),
          _buildDetailRow('ID', _uuid),
          
          const SizedBox(height: 24),
          
          // Signature Line
          Divider(color: AelianaColors.ghost.withOpacity(0.3)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AUTHORIZED SIGNATURE',
                style: GoogleFonts.inter(fontSize: 8, color: AelianaColors.ghost),
              ),
              if (_isAwakened)
                Icon(LucideIcons.check, color: AelianaColors.hyperGold, size: 16)
                    .animate().scale(duration: 300.ms, curve: Curves.elasticOut),
            ],
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0)
     .animate(target: _isAwakened ? 1 : 0).shimmer(duration: 1000.ms, color: AelianaColors.hyperGold);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AelianaColors.ghost,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintButton() {
    return GestureDetector(
      onTapDown: (_) {
         _holdController.forward();
         HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        if (!_isAwakened) _holdController.reverse();
      },
      onTapCancel: () {
        if (!_isAwakened) _holdController.reverse();
      },
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AelianaColors.carbon,
              border: Border.all(
                color: Color.lerp(AelianaColors.ghost.withOpacity(0.3), AelianaColors.hyperGold, _holdController.value)!,
                width: 2,
              ),
              boxShadow: [
                 BoxShadow(
                  color: AelianaColors.hyperGold.withOpacity(_holdController.value * 0.6),
                  blurRadius: 20 * _holdController.value,
                  spreadRadius: 2 * _holdController.value,
                 )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fill effect
                Container(
                  width: 80 * _holdController.value,
                  height: 80 * _holdController.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AelianaColors.hyperGold.withOpacity(0.2),
                  ),
                ),
                Icon(
                  LucideIcons.fingerprint,
                  size: 40,
                  color: Color.lerp(AelianaColors.ghost, AelianaColors.hyperGold, _holdController.value),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
