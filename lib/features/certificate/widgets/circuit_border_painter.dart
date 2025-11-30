import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sable/core/theme/aureal_theme.dart';

class CircuitBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 1. Background Gradient (Deep Blue/Black)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          const Color(0xFF0A1A2F), // Deep blue center
          const Color(0xFF020609), // Black edges
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Paints
    final cyanPaint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final cyanGlowPaint = Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.4)
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..style = PaintingStyle.stroke;

    final darkCyanPaint = Paint()
      ..color = const Color(0xFF005F66)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final goldPaint = Paint()
      ..color = AurealColors.hyperGold
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 2. Outer Frame (Complex)
    final outerPath = Path();
    const double cornerSize = 40;
    const double inset = 10;
    
    // Top Left
    outerPath.moveTo(inset + cornerSize, inset);
    outerPath.lineTo(inset, inset);
    outerPath.lineTo(inset, inset + cornerSize);
    
    // Top Right
    outerPath.moveTo(size.width - inset - cornerSize, inset);
    outerPath.lineTo(size.width - inset, inset);
    outerPath.lineTo(size.width - inset, inset + cornerSize);
    
    // Bottom Right
    outerPath.moveTo(size.width - inset, size.height - inset - cornerSize);
    outerPath.lineTo(size.width - inset, size.height - inset);
    outerPath.lineTo(size.width - inset - cornerSize, size.height - inset);
    
    // Bottom Left
    outerPath.moveTo(inset + cornerSize, size.height - inset);
    outerPath.lineTo(inset, size.height - inset);
    outerPath.lineTo(inset, size.height - inset - cornerSize);

    // Connectors (Straight lines with gaps)
    // Top
    canvas.drawLine(Offset(inset + cornerSize + 10, inset), Offset(size.width - inset - cornerSize - 10, inset), cyanPaint);
    // Bottom
    canvas.drawLine(Offset(inset + cornerSize + 10, size.height - inset), Offset(size.width - inset - cornerSize - 10, size.height - inset), cyanPaint);
    // Left
    canvas.drawLine(Offset(inset, inset + cornerSize + 10), Offset(inset, size.height - inset - cornerSize - 10), cyanPaint);
    // Right
    canvas.drawLine(Offset(size.width - inset, inset + cornerSize + 10), Offset(size.width - inset, size.height - inset - cornerSize - 10), cyanPaint);

    // Draw Outer Glow and Path
    canvas.drawPath(outerPath, cyanGlowPaint);
    canvas.drawPath(outerPath, cyanPaint);

    // 3. Inner Frame (Continuous with chamfered corners)
    const double innerInset = 25;
    const double innerChamfer = 20;
    
    final innerPath = Path();
    innerPath.moveTo(innerInset + innerChamfer, innerInset);
    innerPath.lineTo(size.width - innerInset - innerChamfer, innerInset);
    innerPath.lineTo(size.width - innerInset, innerInset + innerChamfer);
    innerPath.lineTo(size.width - innerInset, size.height - innerInset - innerChamfer);
    innerPath.lineTo(size.width - innerInset - innerChamfer, size.height - innerInset);
    innerPath.lineTo(innerInset + innerChamfer, size.height - innerInset);
    innerPath.lineTo(innerInset, size.height - innerInset - innerChamfer);
    innerPath.lineTo(innerInset, innerInset + innerChamfer);
    innerPath.close();

    canvas.drawPath(innerPath, darkCyanPaint);
    
    // 4. Circuit Traces (Decorative lines)
    _drawCircuitTraces(canvas, size, cyanPaint, goldPaint);
    
    // 5. Gold Accents
    final goldPath = Path();
    // Top center accent
    goldPath.moveTo(size.width / 2 - 40, innerInset - 5);
    goldPath.lineTo(size.width / 2 + 40, innerInset - 5);
    goldPath.moveTo(size.width / 2 - 30, innerInset);
    goldPath.lineTo(size.width / 2, innerInset + 10);
    goldPath.lineTo(size.width / 2 + 30, innerInset);
    
    // Bottom center accent
    goldPath.moveTo(size.width / 2 - 40, size.height - innerInset + 5);
    goldPath.lineTo(size.width / 2 + 40, size.height - innerInset + 5);
    
    canvas.drawPath(goldPath, goldPaint);
  }

  void _drawCircuitTraces(Canvas canvas, Size size, Paint cyanPaint, Paint goldPaint) {
    final thinCyan = Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Top Left Traces
    _drawTrace(canvas, Offset(40, 40), Offset(80, 40), thinCyan);
    _drawTrace(canvas, Offset(40, 50), Offset(70, 50), thinCyan);
    _drawTrace(canvas, Offset(50, 40), Offset(50, 70), thinCyan);

    // Top Right Traces
    _drawTrace(canvas, Offset(size.width - 40, 40), Offset(size.width - 80, 40), thinCyan);
    _drawTrace(canvas, Offset(size.width - 40, 50), Offset(size.width - 70, 50), thinCyan);

    // Bottom Left Traces
    _drawTrace(canvas, Offset(40, size.height - 40), Offset(80, size.height - 40), thinCyan);
    
    // Bottom Right Traces
    _drawTrace(canvas, Offset(size.width - 40, size.height - 40), Offset(size.width - 80, size.height - 40), thinCyan);
    
    // Random nodes
    final dotPaint = Paint()..color = AurealColors.plasmaCyan;
    canvas.drawCircle(Offset(80, 40), 2, dotPaint);
    canvas.drawCircle(Offset(size.width - 80, 40), 2, dotPaint);
    canvas.drawCircle(Offset(80, size.height - 40), 2, dotPaint);
    canvas.drawCircle(Offset(size.width - 80, size.height - 40), 2, dotPaint);
  }

  void _drawTrace(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
