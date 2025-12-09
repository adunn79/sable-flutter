import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

/// A magical orb widget with flowing, shifting colors
/// Responds to speech activity with more intense animations
class MagicOrbWidget extends StatefulWidget {
  final double size;
  final bool isActive; // True when AI is speaking/listening

  const MagicOrbWidget({
    super.key,
    this.size = 68,
    this.isActive = false,
  });

  @override
  State<MagicOrbWidget> createState() => _MagicOrbWidgetState();
}

class _MagicOrbWidgetState extends State<MagicOrbWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _colorShiftController;

  @override
  void initState() {
    super.initState();

    // Slow rotation for the gradient
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Gentle pulse effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Color shift animation
    _colorShiftController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _colorShiftController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MagicOrbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Speed up animations when active (speaking/listening)
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _rotationController.duration = const Duration(seconds: 3);
        _pulseController.duration = const Duration(milliseconds: 800);
      } else {
        _rotationController.duration = const Duration(seconds: 8);
        _pulseController.duration = const Duration(milliseconds: 2000);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotationController,
        _pulseController,
        _colorShiftController,
      ]),
      builder: (context, child) {
        final pulseScale = 1.0 + (_pulseController.value * 0.08);
        final rotation = _rotationController.value * 2 * math.pi;
        final colorShift = _colorShiftController.value;

        return Transform.scale(
          scale: pulseScale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Outer glow
                BoxShadow(
                  color: _getGlowColor(colorShift).withOpacity(0.4),
                  blurRadius: widget.isActive ? 25 : 15,
                  spreadRadius: widget.isActive ? 8 : 4,
                ),
                // Inner glow
                BoxShadow(
                  color: _getSecondaryColor(colorShift).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomPaint(
              painter: _OrbPainter(
                rotation: rotation,
                colorShift: colorShift,
                isActive: widget.isActive,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getGlowColor(double shift) {
    // Use app theme colors
    const colors = [
      AelianaColors.plasmaCyan,    // Teal
      AelianaColors.hyperGold,     // Lavender
      AelianaColors.plasmaCyan,    // Teal
    ];
    return _interpolateColors(colors, shift);
  }

  Color _getSecondaryColor(double shift) {
    const colors = [
      AelianaColors.hyperGold,     // Lavender
      AelianaColors.plasmaCyan,    // Teal
      AelianaColors.hyperGold,     // Lavender
    ];
    return _interpolateColors(colors, shift);
  }

  Color _interpolateColors(List<Color> colors, double t) {
    final index = (t * (colors.length - 1)).floor();
    final localT = (t * (colors.length - 1)) - index;
    return Color.lerp(colors[index], colors[(index + 1) % colors.length], localT)!;
  }
}

class _OrbPainter extends CustomPainter {
  final double rotation;
  final double colorShift;
  final bool isActive;

  _OrbPainter({
    required this.rotation,
    required this.colorShift,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base orb gradient (obsidian/carbon background matching app theme)
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AelianaColors.carbon,      // Slate blue center
          AelianaColors.obsidian,    // Deep navy edge
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, basePaint);

    // Flowing color layer 1 (plasmaCyan/teal wave)
    _drawFlowingLayer(
      canvas,
      center,
      radius,
      rotation,
      [
        AelianaColors.plasmaCyan.withOpacity(0.6),
        AelianaColors.plasmaCyan.withOpacity(0.3),
        Colors.transparent,
      ],
      0.3,
    );

    // Flowing color layer 2 (hyperGold/lavender wave)
    _drawFlowingLayer(
      canvas,
      center,
      radius,
      rotation + math.pi * 0.7,
      [
        AelianaColors.hyperGold.withOpacity(0.5),
        AelianaColors.hyperGold.withOpacity(0.2),
        Colors.transparent,
      ],
      0.4,
    );

    // Flowing color layer 3 (plasmaCyan darker wave)
    _drawFlowingLayer(
      canvas,
      center,
      radius,
      rotation + math.pi * 1.4,
      [
        AelianaColors.plasmaCyan.withOpacity(0.4),
        AelianaColors.plasmaCyan.withOpacity(0.15),
        Colors.transparent,
      ],
      0.35,
    );

    // Bright highlight spot (simulates light reflection)
    final highlightOffset = Offset(
      center.dx + radius * 0.3 * math.cos(rotation * 0.5 - 0.5),
      center.dy + radius * 0.3 * math.sin(rotation * 0.5 - 0.5) - radius * 0.2,
    );
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.8),
          Colors.white.withOpacity(0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: highlightOffset, radius: radius * 0.4));
    canvas.drawCircle(highlightOffset, radius * 0.4, highlightPaint);

    // Rim light (app theme colors)
    final rimPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          AelianaColors.hyperGold.withOpacity(0.6),
          AelianaColors.plasmaCyan.withOpacity(0.4),
          AelianaColors.hyperGold.withOpacity(0.5),
          AelianaColors.plasmaCyan.withOpacity(0.6),
        ],
        transform: GradientRotation(rotation),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, rimPaint);
  }

  void _drawFlowingLayer(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    List<Color> colors,
    double scale,
  ) {
    final layerCenter = Offset(
      center.dx + radius * scale * math.cos(angle),
      center.dy + radius * scale * math.sin(angle),
    );

    final paint = Paint()
      ..shader = RadialGradient(
        colors: colors,
      ).createShader(Rect.fromCircle(center: layerCenter, radius: radius * 0.8));

    canvas.drawCircle(layerCenter, radius * 0.8, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.colorShift != colorShift ||
        oldDelegate.isActive != isActive;
  }
}
