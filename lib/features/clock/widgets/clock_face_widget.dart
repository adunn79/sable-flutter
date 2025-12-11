import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clock display styles - Best-in-class from App Store research
enum ClockStyle {
  digital,   // Large digital display (default)
  analog,    // Traditional analog clock face
  float,     // Floating time that drifts (burn-in protection)
  minimal,   // Ultra-clean, time only
  flip,      // Retro flip-clock style
}

/// Color themes for clock
enum ClockColorTheme {
  white,     // Classic white/gray
  cyan,      // Aeliana cyan/teal accent
  gold,      // Warm gold accent
  red,       // Night mode red
  purple,    // Premium purple
}

/// A clock face widget that can display multiple clock styles
/// Supports Digital, Analog, Float, Minimal, and Flip styles
class ClockFaceWidget extends StatefulWidget {
  final ClockStyle style;
  final bool use24Hour;
  final double size;
  final ClockColorTheme colorTheme;
  final bool nightMode;
  final String? nextAlarmTime;
  final String? weatherTemp;
  final String? weatherCondition;
  final bool showDate;
  final bool showSeconds;

  const ClockFaceWidget({
    super.key,
    this.style = ClockStyle.digital,
    this.use24Hour = false,
    this.size = 200,
    this.colorTheme = ClockColorTheme.white,
    this.nightMode = false,
    this.nextAlarmTime,
    this.weatherTemp,
    this.weatherCondition,
    this.showDate = true,
    this.showSeconds = false,
  });

  @override
  State<ClockFaceWidget> createState() => _ClockFaceWidgetState();
}

class _ClockFaceWidgetState extends State<ClockFaceWidget> with TickerProviderStateMixin {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  
  // For float animation (burn-in protection)
  late AnimationController _floatController;
  double _floatX = 0;
  double _floatY = 0;
  
  // For flip animation
  late AnimationController _flipController;
  int _lastMinute = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final wasMinute = _currentTime.minute;
        setState(() {
          _currentTime = DateTime.now();
        });
        
        // Trigger flip animation on minute change
        if (_currentTime.minute != wasMinute && widget.style == ClockStyle.flip) {
          _triggerFlipAnimation();
        }
      }
    });
    
    // Float animation - slow random drift
    _floatController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..addListener(() {
      if (widget.style == ClockStyle.float && mounted) {
        setState(() {
          _floatX = math.sin(_floatController.value * 2 * math.pi) * 20;
          _floatY = math.cos(_floatController.value * 2 * math.pi) * 10;
        });
      }
    });
    _floatController.repeat();
    
    // Flip animation
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }
  
  void _triggerFlipAnimation() {
    _flipController.forward(from: 0);
  }

  @override
  void dispose() {
    _timer.cancel();
    _floatController.dispose();
    _flipController.dispose();
    super.dispose();
  }
  
  /// Get colors based on theme and night mode
  Color get primaryColor {
    if (widget.nightMode) return const Color(0xFFFF3B30); // Apple red
    
    switch (widget.colorTheme) {
      case ClockColorTheme.white:
        return Colors.white;
      case ClockColorTheme.cyan:
        return const Color(0xFF00BFA5); // Aeliana cyan
      case ClockColorTheme.gold:
        return const Color(0xFFFFD700); // Gold
      case ClockColorTheme.red:
        return const Color(0xFFFF3B30); // Apple red
      case ClockColorTheme.purple:
        return const Color(0xFF9C27B0); // Purple
    }
  }
  
  Color get secondaryColor => primaryColor.withOpacity(0.6);

  @override
  Widget build(BuildContext context) {
    Widget clockWidget;
    
    switch (widget.style) {
      case ClockStyle.digital:
        clockWidget = _buildDigitalClock();
        break;
      case ClockStyle.analog:
        clockWidget = _buildAnalogClock();
        break;
      case ClockStyle.float:
        clockWidget = _buildFloatClock();
        break;
      case ClockStyle.minimal:
        clockWidget = _buildMinimalClock();
        break;
      case ClockStyle.flip:
        clockWidget = _buildFlipClock();
        break;
    }
    
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          clockWidget,
          
          if (widget.showDate && widget.style != ClockStyle.minimal) ...[
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d').format(_currentTime),
              style: GoogleFonts.inter(
                color: secondaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          
          // Weather display
          if (widget.weatherTemp != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud, color: secondaryColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.weatherTemp!,
                  style: GoogleFonts.inter(
                    color: secondaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.weatherCondition != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.weatherCondition!,
                    style: GoogleFonts.inter(
                      color: secondaryColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ],
          
          // Next alarm
          if (widget.nextAlarmTime != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.alarm, color: secondaryColor.withOpacity(0.7), size: 14),
                const SizedBox(width: 6),
                Text(
                  widget.nextAlarmTime!,
                  style: GoogleFonts.inter(
                    color: secondaryColor.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDigitalClock() {
    final timeString = widget.use24Hour 
        ? DateFormat('HH:mm').format(_currentTime)
        : DateFormat('h:mm').format(_currentTime);
    final amPm = DateFormat('a').format(_currentTime);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          timeString,
          style: GoogleFonts.spaceGrotesk(
            color: primaryColor,
            fontSize: widget.size * 0.6,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
        if (!widget.use24Hour)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              amPm,
              style: GoogleFonts.spaceGrotesk(
                color: secondaryColor,
                fontSize: widget.size * 0.15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        if (widget.showSeconds)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 8),
            child: Text(
              ':${_currentTime.second.toString().padLeft(2, '0')}',
              style: GoogleFonts.spaceGrotesk(
                color: secondaryColor,
                fontSize: widget.size * 0.2,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildMinimalClock() {
    // Ultra clean - just time, nothing else
    final timeString = widget.use24Hour 
        ? DateFormat('HH:mm').format(_currentTime)
        : DateFormat('h:mm').format(_currentTime);
        
    return Text(
      timeString,
      style: GoogleFonts.inter(
        color: primaryColor,
        fontSize: widget.size * 0.8,
        fontWeight: FontWeight.w100,
        letterSpacing: -4,
        height: 1,
      ),
    );
  }
  
  Widget _buildFloatClock() {
    // Same as digital but with drift offset
    return Transform.translate(
      offset: Offset(_floatX, _floatY),
      child: _buildDigitalClock(),
    );
  }
  
  Widget _buildFlipClock() {
    // Retro flip-clock style
    final hours = widget.use24Hour 
        ? _currentTime.hour.toString().padLeft(2, '0')
        : (_currentTime.hour % 12 == 0 ? 12 : _currentTime.hour % 12).toString().padLeft(2, '0');
    final minutes = _currentTime.minute.toString().padLeft(2, '0');
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFlipDigit(hours[0]),
        _buildFlipDigit(hours[1]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            ':',
            style: GoogleFonts.robotoMono(
              color: primaryColor,
              fontSize: widget.size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _flipController,
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_flipController.value * math.pi / 2 * 0.1),
              child: child,
            );
          },
          child: _buildFlipDigit(minutes[0]),
        ),
        _buildFlipDigit(minutes[1]),
        if (!widget.use24Hour)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              _currentTime.hour >= 12 ? 'PM' : 'AM',
              style: GoogleFonts.robotoMono(
                color: secondaryColor,
                fontSize: widget.size * 0.12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildFlipDigit(String digit) {
    return Container(
      width: widget.size * 0.28,
      height: widget.size * 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          digit,
          style: GoogleFonts.robotoMono(
            color: primaryColor,
            fontSize: widget.size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalogClock() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _AnalogClockPainter(
          time: _currentTime,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
        ),
      ),
    );
  }
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime time;
  final Color primaryColor;
  final Color secondaryColor;

  _AnalogClockPainter({
    required this.time,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw clock face outline
    final outlinePaint = Paint()
      ..color = secondaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 4, outlinePaint);

    // Draw hour numbers
    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30) * (math.pi / 180) - math.pi / 2;
      final numberRadius = radius * 0.75;
      final numberPoint = Offset(
        center.dx + numberRadius * math.cos(angle),
        center.dy + numberRadius * math.sin(angle),
      );
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: i.toString(),
          style: TextStyle(
            color: primaryColor,
            fontSize: radius * 0.18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          numberPoint.dx - textPainter.width / 2,
          numberPoint.dy - textPainter.height / 2,
        ),
      );
    }
    
    // Draw minute tick marks
    for (int i = 0; i < 60; i++) {
      if (i % 5 != 0) {
        final angle = (i * 6) * (math.pi / 180) - math.pi / 2;
        final outerPoint = Offset(
          center.dx + (radius - 6) * math.cos(angle),
          center.dy + (radius - 6) * math.sin(angle),
        );
        final innerPoint = Offset(
          center.dx + (radius - 10) * math.cos(angle),
          center.dy + (radius - 10) * math.sin(angle),
        );
        final markerPaint = Paint()
          ..color = secondaryColor.withOpacity(0.4)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(innerPoint, outerPoint, markerPaint);
      }
    }

    // Calculate hand angles
    final secondAngle = (time.second * 6) * (math.pi / 180) - math.pi / 2;
    final minuteAngle = (time.minute * 6 + time.second * 0.1) * (math.pi / 180) - math.pi / 2;
    final hourAngle = (time.hour % 12 * 30 + time.minute * 0.5) * (math.pi / 180) - math.pi / 2;

    // Draw hands
    _drawHand(canvas, center, hourAngle, radius * 0.45, 6, primaryColor);
    _drawHand(canvas, center, minuteAngle, radius * 0.65, 4, primaryColor);
    _drawHand(canvas, center, secondAngle, radius * 0.75, 2, primaryColor);

    // Draw center dot
    final centerDotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, centerDotPaint);
  }

  void _drawHand(Canvas canvas, Offset center, double angle, double length, 
      double width, Color color) {
    final endPoint = Offset(
      center.dx + length * math.cos(angle),
      center.dy + length * math.sin(angle),
    );
    
    final handPaint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, endPoint, handPaint);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) {
    return oldDelegate.time.second != time.second;
  }
}
