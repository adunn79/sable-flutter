import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/aeliana_theme.dart';

/// 17+ Age Gate for Private Space
/// Must be confirmed before accessing Private Space for the first time
class PrivateSpaceAgeGate extends StatelessWidget {
  final VoidCallback onConfirmed;
  final VoidCallback onDeclined;

  const PrivateSpaceAgeGate({
    super.key,
    required this.onConfirmed,
    required this.onDeclined,
  });

  Future<void> _handleConfirm(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('private_space_age_confirmed', true);
    onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mask icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AelianaColors.hyperGold.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    '🎭',
                    style: TextStyle(fontSize: 64),
                  ),
                ),
                const SizedBox(height: 32),
                
                Text(
                  'Private Space',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A premium sanctuary for mature exploration',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Age confirmation box
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AelianaColors.carbon,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AelianaColors.hyperGold.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.alertTriangle,
                        color: AelianaColors.hyperGold,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Age Verification Required',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This area contains mature themes intended for adults 17 years or older. Content here is private and never shared with the rest of the app.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleConfirm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AelianaColors.hyperGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'I am 17 or older',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Decline button
                TextButton(
                  onPressed: onDeclined,
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
