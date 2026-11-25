import 'package:flutter/material.dart';

import '../network/school_attendance_api.dart';
import '../theme.dart';
import 'school_ui.dart';
import 'design_tokens.dart';

const attendanceTeal = Color(0xFF236A7C);
const attendanceSoft = Color(0xFFECF2FD);

const attendanceStatusColors = {
  'HADIR': Color(0xFF1E7D4F),
  'TERLAMBAT': Color(0xFFB26A00),
  'IZIN': Color(0xFF2768B2),
  'SAKIT': Color(0xFF6A4BB2),
  'ALFA': Color(0xFFC62828),
  'PENGECUALIAN_SAH': Color(0xFF546E7A),
  'BELUM_DIISI': muted,
};

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatHhmm(DateTime? t) => t == null
    ? '-'
    : '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';

/// "20 Nov 2026"
String formatDateId(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Dari "2026-11-20" -> "20 Nov 2026".
String formatYmd(String ymd) {
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : formatDateId(d);
}

class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) => SchoolStatus(
    status,
    label: attendanceStatusLabels[status] ?? status,
    color: attendanceStatusColors[status] ?? muted,
  );
}

/// Kotak angka kecil berwarna, mis. "Hadir 12".
class AttendanceCountTile extends StatelessWidget {
  const AttendanceCountTile({
    super.key,
    required this.status,
    required this.count,
  });
  final String status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = attendanceStatusColors[status] ?? muted;
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(SchoolDesign.controlRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            attendanceStatusLabels[status] ?? status,
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// Warna aksen pembeda antar bagian.
const sectionBlue = Color(0xFF2768B2);
const sectionOrange = Color(0xFFB26A00);
const sectionGreen = Color(0xFF1E7D4F);
const sectionPurple = Color(0xFF6A4BB2);

/// Kartu bagian dengan header berwarna sebagai batas pembeda.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SchoolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SchoolSectionTitle(title, icon: icon, color: color),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    ),
  );
}

/// Compatibility wrapper; feature pages use the same solid context header.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SchoolContextHeader(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
    ),
  );
}

/// Warna header & baris selang-seling untuk DataTable presensi.
const tableHeadingColor = WidgetStatePropertyAll(attendanceSoft);
const tableHeadingStyle = TextStyle(
  color: navy,
  fontWeight: FontWeight.w700,
  fontSize: 12,
);
Color? zebra(int index) => index.isOdd ? const Color(0xFFF8FAFE) : null;

/// Pil kecil berwarna, mis. "3 belum".
class ColorPill extends StatelessWidget {
  const ColorPill(this.text, {super.key, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      SchoolStatus(text, label: text, color: color, icon: icon);
}

/// Judul tahap bernomor untuk alur bertahap.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.title,
    required this.caption,
  });
  final int step;
  final String title, caption;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 12,
        backgroundColor: navy,
        foregroundColor: Colors.white,
        child: Text('$step', style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(caption, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ],
  );
}
