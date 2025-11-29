import 'package:flutter/material.dart';
import 'package:sable/core/theme/aureal_theme.dart';

class CircuitBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cyanPaint = Paint()
      ..color = AurealColors.plasmaCyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final goldPaint = Paint()
      ..color = AurealColors.hyperGold
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw outer cyan border with corners
    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerPath = Path();
    
    // Top left corner
    outerPath.moveTo(20, 0);
    outerPath.lineTo(0, 0);
    outerPath.lineTo(0, 20);
    
    // Top right corner
    outerPath.moveTo(size.width - 20, 0);
    outerPath.lineTo(size.width, 0);
    outerPath.lineTo(size.width, 20);
    
    // Bottom right corner
    outerPath.moveTo(size.width, size.height - 20);
    outerPath.lineTo(size.width, size.height);
    outerPath.lineTo(size.width - 20, size.height);
    
    // Bottom left corner
    outerPath.moveTo(20, size.height);
    outerPath.lineTo(0, size.height);
    outerPath.lineTo(0, size.height - 20);
    
    canvas.drawPath(outerPath, cyanPaint);
    
    // Draw inner gold border
    final innerRect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final innerPath = Path();
    
    // Top left corner
    innerPath.moveTo(28, 8);
    innerPath.lineTo(8, 8);
    innerPath.lineTo(8, 28);
    
    // Top right corner
    innerPath.moveTo(size.width - 28, 8);
    innerPath.lineTo(size.width - 8, 8);
    innerPath.lineTo(size.width - 8, 28);
    
    // Bottom right corner
    innerPath.moveTo(size.width - 8, size.height - 28);
    innerPath.lineTo(size.width - 8, size.height - 8);
    innerPath.lineTo(size.width - 28, size.height - 8);
    
    // Bottom left corner
    innerPath.moveTo(28, size.height - 8);
    innerPath.lineTo(8, size.height - 8);
    innerPath.lineTo(8, size.height - 28);
    
    canvas.drawPath(innerPath, goldPaint);
    
    // Add some circuit-like connection points
    final dotPaint = Paint()
      ..color = AurealColors.hyperGold
      ..style = PaintingStyle.fill;
    
    // Top corners
    canvas.drawCircle(Offset(40, 12), 2, dotPaint);
    canvas.drawCircle(Offset(size.width - 40, 12), 2, dotPaint);
    
    // Bottom corners
    canvas.drawCircle(Offset(40, size.height - 12), 2, dotPaint);
    canvas.drawCircle(Offset(size.width - 40, size.height - 12), 2, dotPaint);
    
    // Side connection points
    canvas.drawCircle(Offset(12, size.height / 2), 2, dotPaint);
    canvas.drawCircle(Offset(size.width - 12, size.height / 2), 2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
