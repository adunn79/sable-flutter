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
        radius: 1.0,
        colors: [
          const Color(0xFF0F172A), // Slate 900
          const Color(0xFF020617), // Slate 950
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Paints
    final cyanPaint = Paint()
      ..color = const Color(0xFF06B6D4) // Cyan 500
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cyanGlowPaint = Paint()
      ..color = const Color(0xFF22D3EE).withOpacity(0.5) // Cyan 400
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.stroke;

    final darkBluePaint = Paint()
      ..color = const Color(0xFF1E293B) // Slate 800
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final goldPaint = Paint()
      ..color = const Color(0xFFF59E0B) // Amber 500
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 2. Complex Outer Frame
    // Multiple parallel lines for the circuit look
    _drawComplexFrame(canvas, size, 10, cyanPaint);
    _drawComplexFrame(canvas, size, 16, darkBluePaint);
    _drawComplexFrame(canvas, size, 22, cyanPaint..strokeWidth = 0.5);

    // 3. Corner Accents (The "Tech" look)
    _drawCornerAccents(canvas, size, cyanPaint, cyanGlowPaint);

    // 4. Inner Frame (The content container)
    final innerRect = Rect.fromLTWH(
      40, 
      40, 
      size.width - 80, 
      size.height - 80
    );
    
    // Chamfered corners for inner frame
    final innerPath = Path()
      ..moveTo(innerRect.left + 20, innerRect.top)
      ..lineTo(innerRect.right - 20, innerRect.top)
      ..lineTo(innerRect.right, innerRect.top + 20)
      ..lineTo(innerRect.right, innerRect.bottom - 20)
      ..lineTo(innerRect.right - 20, innerRect.bottom)
      ..lineTo(innerRect.left + 20, innerRect.bottom)
      ..lineTo(innerRect.left, innerRect.bottom - 20)
      ..lineTo(innerRect.left, innerRect.top + 20)
      ..close();

    canvas.drawPath(innerPath, darkBluePaint);
    canvas.drawPath(innerPath, cyanPaint..strokeWidth = 0.5);

    // 5. Gold Accents (Top and Bottom Center)
    _drawGoldAccents(canvas, size, goldPaint);
    
    // 6. Circuit Traces (Connecting lines)
    _drawCircuitTraces(canvas, size, cyanPaint);
  }

  void _drawComplexFrame(Canvas canvas, Size size, double inset, Paint paint) {
    final path = Path();
    const double cornerSize = 30;
    
    // Top Left
    path.moveTo(inset + cornerSize, inset);
    path.lineTo(inset, inset);
    path.lineTo(inset, inset + cornerSize);
    
    // Top Right
    path.moveTo(size.width - inset - cornerSize, inset);
    path.lineTo(size.width - inset, inset);
    path.lineTo(size.width - inset, inset + cornerSize);
    
    // Bottom Right
    path.moveTo(size.width - inset, size.height - inset - cornerSize);
    path.lineTo(size.width - inset, size.height - inset);
    path.lineTo(size.width - inset - cornerSize, size.height - inset);
    
    // Bottom Left
    path.moveTo(inset + cornerSize, size.height - inset);
    path.lineTo(inset, size.height - inset);
    path.lineTo(inset, size.height - inset - cornerSize);
    
    // Connectors
    path.moveTo(inset + cornerSize + 10, inset);
    path.lineTo(size.width - inset - cornerSize - 10, inset);
    
    path.moveTo(inset + cornerSize + 10, size.height - inset);
    path.lineTo(size.width - inset - cornerSize - 10, size.height - inset);
    
    path.moveTo(inset, inset + cornerSize + 10);
    path.lineTo(inset, size.height - inset - cornerSize - 10);
    
    path.moveTo(size.width - inset, inset + cornerSize + 10);
    path.lineTo(size.width - inset, size.height - inset - cornerSize - 10);
    
    canvas.drawPath(path, paint);
  }

  void _drawCornerAccents(Canvas canvas, Size size, Paint paint, Paint glowPaint) {
    final path = Path();
    const double cornerSize = 20;
    const double offset = 5;
    
    // Top Left
    path.moveTo(offset + cornerSize, offset);
    path.lineTo(offset, offset);
    path.lineTo(offset, offset + cornerSize);
    
    // Draw for all corners... (simplified for brevity, actual implementation would rotate/translate)
    // For now, let's just draw circles at corners for the "node" look
    canvas.drawCircle(const Offset(10, 10), 3, glowPaint);
    canvas.drawCircle(Offset(size.width - 10, 10), 3, glowPaint);
    canvas.drawCircle(Offset(size.width - 10, size.height - 10), 3, glowPaint);
    canvas.drawCircle(Offset(10, size.height - 10), 3, glowPaint);
  }

  void _drawGoldAccents(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    
    // Top Chevron
    path.moveTo(cx - 30, 25);
    path.lineTo(cx, 35);
    path.lineTo(cx + 30, 25);
    
    // Bottom Chevron
    path.moveTo(cx - 30, size.height - 25);
    path.lineTo(cx, size.height - 35);
    path.lineTo(cx + 30, size.height - 25);
    
    canvas.drawPath(path, paint);
  }

  void _drawCircuitTraces(Canvas canvas, Size size, Paint paint) {
    // Random tech lines
    final path = Path();
    
    // Left side traces
    path.moveTo(0, size.height * 0.3);
    path.lineTo(30, size.height * 0.3);
    path.lineTo(40, size.height * 0.35);
    
    path.moveTo(0, size.height * 0.7);
    path.lineTo(20, size.height * 0.7);
    path.lineTo(30, size.height * 0.65);
    
    // Right side traces
    path.moveTo(size.width, size.height * 0.4);
    path.lineTo(size.width - 30, size.height * 0.4);
    path.lineTo(size.width - 40, size.height * 0.45);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
