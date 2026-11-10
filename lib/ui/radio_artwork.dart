import 'package:flutter/material.dart';
import 'radio_theme.dart';

/// 简单的声波封面完全由矢量绘制，离线可用，也不受电台缺少 Logo 影响。
class RadioArtwork extends CustomPainter {
  const RadioArtwork(this.colors);
  final RadioPalette colors;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.art, colors.accent],
        ).createShader(bounds),
    );
    final center = Offset(size.width * .78, size.height * .34);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        center,
        size.width * (.17 + i * .13),
        Paint()
          ..color = Colors.white.withValues(alpha: .19 - i * .025)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }
    canvas.drawCircle(
      center,
      size.width * .16,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFE5BA),
                colors.art.withValues(alpha: .2),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.width * .16),
            ),
    );
    final wave = Path()
      ..moveTo(0, size.height * .63)
      ..cubicTo(
        size.width * .32,
        size.height * .34,
        size.width * .58,
        size.height * .96,
        size.width,
        size.height * .63,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      wave,
      Paint()..color = colors.accent.withValues(alpha: .26),
    );
  }

  @override
  bool shouldRepaint(covariant RadioArtwork oldDelegate) =>
      oldDelegate.colors.accent != colors.accent;
}
