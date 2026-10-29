import 'package:flutter/material.dart';
import '../theme.dart';
import 'shared.dart';

void unavailable(BuildContext context, String title) => showDetails(
  context,
  title: title,
  child: const Text(
    'Fitur belum tersedia. Halaman ini akan dikembangkan pada implementasi modul terkait.',
  ),
);

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.caption, this.onTap});
  final String title;
  final String? caption;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (caption != null)
          InkWell(
            onTap: onTap,
            child: Text(
              caption!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF236A7C)),
            ),
          ),
      ],
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.color = const Color(0xFFDDF8EE),
    this.foreground = const Color(0xFF12634C),
  });
  final String text;
  final Color color, foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric(
    this.label,
    this.value, {
    super.key,
    this.icon = Icons.insights_outlined,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
            Icon(icon, size: 21, color: const Color(0xFF236A7C)),
          ],
        ),
        const SizedBox(height: 13),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );
}

class ActionTile extends StatelessWidget {
  const ActionTile(
    this.title, {
    super.key,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FB),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: navy, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SummaryCounts extends StatelessWidget {
  const SummaryCounts({super.key, required this.items});
  final Map<String, String> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.entries
          .map(
            (e) => SizedBox(
              width:
                  (constraints.maxWidth -
                      8 * (_countColumns(context, constraints.maxWidth) - 1)) /
                  _countColumns(context, constraints.maxWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: e.key == 'Hadir'
                      ? const Color(0xFFEBFBF3)
                      : const Color(0xFFF0F4FE),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 10)),
                    const SizedBox(height: 3),
                    Text(
                      e.value,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.notifications_outlined,
    this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F1FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: const Color(0xFF236A7C), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, size: 18, color: muted),
            ],
          ),
        ),
      ),
    ),
  );
}

// Choose count tiles by their available width and accessibility text size.
int _countColumns(BuildContext context, double width) {
  final minimum = 84 * MediaQuery.textScalerOf(context).scale(1);
  return (width / (minimum + 8)).floor().clamp(1, 4);
}
