import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../core/theme/aureal_theme.dart';
import '../onboarding/services/onboarding_state_service.dart'; 

class AurealSplashScreen extends StatefulWidget {
  const AurealSplashScreen({super.key});

  @override
  State<AurealSplashScreen> createState() => _AurealSplashScreenState();
}

class _AurealSplashScreenState extends State<AurealSplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingAndNavigate();
  }

  Future<void> _checkOnboardingAndNavigate() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 4));
    
    if (!mounted) return;

    // Check onboarding status
    final stateService = await OnboardingStateService.create();
    final isComplete = stateService.isOnboardingComplete;
    
    debugPrint('Onboarding complete: $isComplete');
    debugPrint('User name: ${stateService.userName}');

    if (!mounted) return;

    if (isComplete && stateService.userName != null) {
      // Navigate to main app only if onboarding is complete AND user data exists
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Navigate to onboarding
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurealColors.obsidian, // #0A0A0E
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // THE SYNAPSE LOGO (Code Drawn)
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: SynapseLogoPainter(),
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms) // Fade in
            .scale(duration: 600.ms, curve: Curves.easeOutBack) // Pop in
            .then()
            .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.2)) // Light sheen
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scaleXY(end: 1.05, duration: 2000.ms, curve: Curves.easeInOutQuad), // Breathing effect

            const SizedBox(height: 40),

            // BRAND NAME
            Text(
              "AUREAL",
              style: GoogleFonts.spaceGrotesk(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 8.0,
                color: AurealColors.stardust,
              ),
            )
            .animate()
            .fadeIn(delay: 500.ms, duration: 600.ms)
            .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 12),

            // TAGLINE
            Text(
              "Living technology.",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AurealColors.plasmaCyan, // Cyan accent for the tagline
                letterSpacing: 1.2,
              ),
            )
            .animate()
            .fadeIn(delay: 1000.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// THE PAINTER: Draws the Logo Programmatically (No Images Required)
// ---------------------------------------------------------------------------
class SynapseLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw the Cyan Arcs (The Synapse)
    final arcPaint = Paint()
      ..color = AurealColors.plasmaCyan // #00F0FF
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4); // Soft neon glow

    // Left Arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.8),
      2.0, // Start angle (roughly bottom left)
      2.3, // Sweep length
      false,
      arcPaint,
    );

    // Right Arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.8),
      -1.15, // Start angle (roughly top right)
      2.3,   // Sweep length
      false,
      arcPaint,
    );

    // 2. Draw the Gold Spark (The Soul)
    final sparkPaint = Paint()
      ..color = AurealColors.hyperGold // #FFD700
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8); // Intense glow

    // Create a 4-pointed star path
    final path = Path();
    final sparkSize = radius * 0.35; // Size of the spark relative to the arcs

    path.moveTo(center.dx, center.dy - sparkSize); // Top
    path.quadraticBezierTo(center.dx, center.dy, center.dx + sparkSize * 0.7, center.dy); // Right Curve
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + sparkSize); // Bottom Curve
    path.quadraticBezierTo(center.dx, center.dy, center.dx - sparkSize * 0.7, center.dy); // Left Curve
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - sparkSize); // Back to Top

    canvas.drawPath(path, sparkPaint);
    
    // 3. Optional: Add a white core to the spark to make it look hot
    final corePaint = Paint()..color = Colors.white.withOpacity(0.8);
    canvas.drawCircle(center, 2.0, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
