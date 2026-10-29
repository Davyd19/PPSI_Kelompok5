import 'package:flutter/material.dart';
import '../theme.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE7EDF5)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08082B50),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class SchoolIdentity extends StatelessWidget {
  const SchoolIdentity({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      CircleAvatar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        radius: 23,
        child: Icon(Icons.school_outlined),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIM Kesiswaan',
              style: TextStyle(
                color: navy,
                fontWeight: FontWeight.w800,
                fontSize: 17,
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

void showDetails(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
