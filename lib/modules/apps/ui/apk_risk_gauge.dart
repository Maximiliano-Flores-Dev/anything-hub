import 'package:flutter/material.dart';

import '../../../core/hub_colors.dart';

class ApkRiskGaugePainter extends CustomPainter {
  ApkRiskGaugePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 10.0;
    final rect = Rect.fromLTWH(
        stroke, stroke, size.width - stroke * 2, size.height * 1.6);
    final bg = Paint()
      ..color = HubColors.linea
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3.14159, 3.14159, false, bg);
    canvas.drawArc(
        rect, 3.14159, 3.14159 * progress.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant ApkRiskGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
