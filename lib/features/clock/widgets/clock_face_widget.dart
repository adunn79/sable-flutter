import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// A clock face widget that can display either digital or analog time
class ClockFaceWidget extends StatefulWidget {
  final bool isAnalog;
  final bool use24Hour;
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final String? nextAlarmTime;
  final String? weatherTemp;
  final String? weatherCondition;

  const ClockFaceWidget({
    super.key,
    this.isAnalog = false,
    this.use24Hour = false,
    this.size = 200,
    this.primaryColor = Colors.white,
    this.secondaryColor = Colors.white54,
    this.nextAlarmTime,
    this.weatherTemp,
    this.weatherCondition,
  });

  @override
  State<ClockFaceWidget> createState() => _ClockFaceWidgetState();
}

class _ClockFaceWidgetState extends State<ClockFaceWidget> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        // Clock display
        widget.isAnalog ? _buildAnalogClock() : _buildDigitalClock(),
        
        const SizedBox(height: 8),
        
        // Date display
        Text(
          DateFormat('EEEE, MMMM d').format(_currentTime),
          style: GoogleFonts.inter(
            color: widget.secondaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        
        // Weather display (under date)
        if (widget.weatherTemp != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud,
                color: widget.secondaryColor.withOpacity(0.8),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                widget.weatherTemp!,
                style: GoogleFonts.inter(
                  color: widget.secondaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.weatherCondition != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.weatherCondition!,
                  style: GoogleFonts.inter(
                    color: widget.secondaryColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ],
        
        // Next alarm (if set)
        if (widget.nextAlarmTime != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.alarm,
                color: widget.secondaryColor.withOpacity(0.7),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                widget.nextAlarmTime!,
                style: GoogleFonts.inter(
                  color: widget.secondaryColor.withOpacity(0.8),
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
            color: widget.primaryColor,
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
                color: widget.secondaryColor,
                fontSize: widget.size * 0.15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnalogClock() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _AnalogClockPainter(
          time: _currentTime,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
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
      
      // Position for numbers (inside the clock face)
      final numberRadius = radius * 0.75;
      final numberPoint = Offset(
        center.dx + numberRadius * math.cos(angle),
        center.dy + numberRadius * math.sin(angle),
      );
      
      // Draw the hour number
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
    
    // Draw small tick marks for minutes (optional, subtle)
    for (int i = 0; i < 60; i++) {
      if (i % 5 != 0) { // Skip hour positions
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

    // Draw hour hand
    _drawHand(canvas, center, hourAngle, radius * 0.45, 6, primaryColor);

    // Draw minute hand
    _drawHand(canvas, center, minuteAngle, radius * 0.65, 4, primaryColor);

    // Draw second hand (sweep)
    _drawHand(canvas, center, secondAngle, radius * 0.75, 2, Colors.red);

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
