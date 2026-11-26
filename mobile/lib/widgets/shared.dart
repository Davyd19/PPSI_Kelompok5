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

/// Pita merek bergradasi (navy -> biru logo) dengan cahaya lembut.
class BrandBand extends StatelessWidget {
  const BrandBand({super.key, required this.child, this.radius = 16});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SchoolBrandPanel(radius: radius, watermark: false, child: child),
  );
}

class SchoolIdentity extends StatelessWidget {
  const SchoolIdentity({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SchoolLogo(size: 42),
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

class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: muted),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat data',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
