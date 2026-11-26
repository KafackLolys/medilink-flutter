import 'package:flutter/material.dart';

/// Fond léger réservé à l'espace médecin : formes organiques et illustration
/// médicale discrète, sans intercepter les interactions des écrans enfants.
class DoctorPageBackground extends StatelessWidget {
  const DoctorPageBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: Theme.of(context).appBarTheme.copyWith(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            foregroundColor: const Color(0xff172554),
            elevation: 0,
            titleTextStyle: const TextStyle(
              color: Color(0xff172554),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xfff5f7fc), Color(0xfff8faff), Color(0xfff1f6ff)],
              ),
            ),
          ),
          const Positioned(
            top: -82,
            right: -72,
            child: _SoftOrb(size: 230, color: Color(0x2463a5f5)),
          ),
          const Positioned(
            bottom: 90,
            left: -110,
            child: _SoftOrb(size: 210, color: Color(0x1c2563eb)),
          ),
          const Positioned(
            top: 24,
            right: 18,
            child: IgnorePointer(
              child: SizedBox(
                width: 126,
                height: 126,
                child: CustomPaint(painter: _MedicalLinePainter()),
              ),
            ),
          ),
          child,
        ],
      ),
      );
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      );
}

class _MedicalLinePainter extends CustomPainter {
  const _MedicalLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x2670a9c7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .05, size.height * .55)
      ..lineTo(size.width * .28, size.height * .55)
      ..lineTo(size.width * .39, size.height * .25)
      ..lineTo(size.width * .52, size.height * .78)
      ..lineTo(size.width * .65, size.height * .43)
      ..lineTo(size.width * .76, size.height * .55)
      ..lineTo(size.width * .96, size.height * .55);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * .5, size.height * .5),
      size.width * .48,
      paint..color = const Color(0x192563eb),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
