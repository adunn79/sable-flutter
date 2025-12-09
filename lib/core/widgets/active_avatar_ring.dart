import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/aeliana_theme.dart';

class ActiveAvatarRing extends StatefulWidget {
  final Widget child;
  final double size;
  final bool isActive;
  final bool showRing; // If false, no ring is shown (just child)

  const ActiveAvatarRing({
    super.key,
    required this.child,
    this.size = 40,
    this.isActive = false,
    this.showRing = true,
  });

  @override
  State<ActiveAvatarRing> createState() => _ActiveAvatarRingState();
}

class _ActiveAvatarRingState extends State<ActiveAvatarRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(ActiveAvatarRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.duration = const Duration(seconds: 1); // Fast spin when active
        _controller.repeat();
      } else {
        _controller.duration = const Duration(seconds: 4); // Slow spin when idle
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showRing) return widget.child;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFF00D4FF), // Cyan
                        Color(0xFF00FF88), // Green
                        Color(0xFFFFD700), // Gold/Yellow
                        Color(0xFFFF6B35), // Orange
                        Color(0xFFFF1493), // Pink/Magenta
                        Color(0xFF9B59B6), // Purple
                        Color(0xFF00D4FF), // Cyan (loop back)
                      ],
                      stops: [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Inner Cutout (to make it a ring)
          Container(
            width: widget.size - 4, // 2px border width
            height: widget.size - 4,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AelianaColors.obsidian, // Matches background
            ),
          ),
          
          // The Child (Avatar)
          SizedBox(
            width: widget.size - 6, // Padding for ring
            height: widget.size - 6,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
