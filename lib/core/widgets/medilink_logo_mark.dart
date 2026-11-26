import 'package:flutter/material.dart';

class _HeartPulsePainter extends CustomPainter {
  _HeartPulsePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final heart = Path()
      ..moveTo(size.width / 2, size.height * .86)
      ..cubicTo(size.width * .36, size.height * .72, size.width * .08,
          size.height * .52, size.width * .08, size.height * .31)
      ..cubicTo(size.width * .08, size.height * .10, size.width * .34,
          size.height * .04, size.width / 2, size.height * .23)
      ..cubicTo(size.width * .66, size.height * .04, size.width * .92,
          size.height * .10, size.width * .92, size.height * .31)
      ..cubicTo(size.width * .92, size.height * .52, size.width * .64,
          size.height * .72, size.width / 2, size.height * .86);
    canvas.drawPath(heart, stroke);

    final pulse = Path()
      ..moveTo(size.width * .13, size.height * .48)
      ..lineTo(size.width * .31, size.height * .48)
      ..lineTo(size.width * .40, size.height * .34)
      ..lineTo(size.width * .51, size.height * .64)
      ..lineTo(size.width * .62, size.height * .41)
      ..lineTo(size.width * .69, size.height * .48)
      ..lineTo(size.width * .87, size.height * .48);
    canvas.drawPath(pulse, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shared MediLink mark used on login and authenticated screens.
class MedilinkLogoMark extends StatelessWidget {
  const MedilinkLogoMark({super.key, this.size = 34, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size.square(size),
          painter: _HeartPulsePainter(color ?? const Color(0xff1769aa)),
        ),
      );
}
