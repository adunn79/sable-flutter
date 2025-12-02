import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Cinematic background with breathing animation and parallax effect
/// Makes the avatar feel alive with subtle movement
class CinematicBackground extends StatefulWidget {
  final String imagePath;
  final bool blur;

  const CinematicBackground({
    super.key,
    required this.imagePath,
    this.blur = false,
  });

  @override
  State<CinematicBackground> createState() => _CinematicBackgroundState();
}

class _CinematicBackgroundState extends State<CinematicBackground>
    with SingleTickerProviderStateMixin {
  
  // 1. BREATHING ANIMATION (Zoom)
  late AnimationController _breathController;
  
  // 2. PARALLAX STATE (Tilt)
  double _xOffset = 0.0;
  double _yOffset = 0.0;
  StreamSubscription<GyroscopeEvent>? _gyroStream;

  @override
  void initState() {
    super.initState();

    // Setup Breathing (Slow Zoom)
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
      lowerBound: 1.0,
      upperBound: 1.05,
    )..repeat(reverse: true);

    // Setup Parallax (Gyroscope)
    // We listen to device tilt and shift the image slightly
    _gyroStream = gyroscopeEvents.listen((GyroscopeEvent event) {
      if (mounted) {
        setState(() {
          // Sensitivity factor (Keep it subtle)
          _xOffset += event.y * 2.0; 
          _yOffset += event.x * 2.0;
          
          // Clamp to prevent image floating too far away
          _xOffset = _xOffset.clamp(-20.0, 20.0);
          _yOffset = _yOffset.clamp(-20.0, 20.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    _gyroStream?.cancel(); // Important: Stop listening to sensors
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // LAYER 1: The Reactive Image
        AnimatedBuilder(
          animation: _breathController,
          builder: (context, child) {
            return Transform.scale(
              scale: _breathController.value, // The Breath
              child: Transform.translate(
                offset: Offset(_xOffset, _yOffset), // The Parallax
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800), // Mood Cross-fade
                  child: Container(
                    key: ValueKey(widget.imagePath), // Identifies image change
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: widget.imagePath.startsWith('http')
                            ? NetworkImage(widget.imagePath) as ImageProvider
                            : AssetImage(widget.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // LAYER 2: The Scrim (Gradient for text readability)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
              stops: const [0.5, 1.0],
            ),
          ),
        ),

        // LAYER 3: Optional Blur (For Settings Page)
        if (widget.blur)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
      ],
    );
  }
}
