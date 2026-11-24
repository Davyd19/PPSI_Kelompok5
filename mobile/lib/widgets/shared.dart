import 'package:flutter/material.dart';
import '../theme.dart';
import 'motion.dart';

export 'motion.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color == Colors.white ? line : color),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080E2A47),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}

/// Pita navy berarsir dengan garis aksen di bawah — padanan pita merek di sidebar portal web.
class BrandBand extends StatelessWidget {
  const BrandBand({super.key, required this.child, this.radius = 16});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final tone = PortalTone.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: navy,
          border: Border(bottom: BorderSide(color: tone.color, width: 3)),
        ),
        child: CustomPaint(
          painter: _HatchPainter(),
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 2;
    for (double x = -size.height; x < size.width; x += 9) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SchoolIdentity extends StatelessWidget {
  const SchoolIdentity({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(Icons.school_outlined, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIM Kesiswaan',
              style: TextStyle(
                color: navy,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -.2,
              ),
            ),
            Text(
              'SMAN 12 Padang',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Detail atau pemberitahuan singkat, tampil sebagai pop-up di tengah layar.
void showDetails(
  BuildContext context, {
  required String title,
  required Widget child,
  IconData? icon,
}) {
  showAppDialog<void>(context, title: title, icon: icon, child: child);
}
