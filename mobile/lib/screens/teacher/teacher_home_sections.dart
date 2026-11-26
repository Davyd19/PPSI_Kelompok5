import 'package:flutter/material.dart';
import '../../app/account_capabilities.dart';
import '../../network/attendance_recap_api.dart';
import '../../network/school_attendance_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../../widgets/school_ui.dart';
import '../../widgets/attendance_widgets.dart';

class TeacherAttendanceSection extends StatelessWidget {
  const TeacherAttendanceSection({
    super.key,
    required this.day,
    required this.loading,
    required this.onOpen,
    required this.onRetry,
    this.error,
  });
  final SchoolDay? day;
  final bool loading;
  final VoidCallback onOpen, onRetry;
  final String? error;
  @override
  Widget build(BuildContext context) {
    if (error != null) return LoadErrorView(message: error!, onRetry: onRetry);
    if (loading && day == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Row(
      children: [
        Expanded(child: _sessionTile('PAGI')),
        const SizedBox(width: 10),
        Expanded(child: _sessionTile('ZUHUR')),
      ],
    );
  }

  Widget _sessionTile(String type) {
    final session = day?.session(type);
    final color = type == 'PAGI' ? sectionBlue : sectionGreen;
    final (status, statusColor) = switch (session?.status) {
      null => ('Belum dibuka', muted),
      'AKTIF' => ('Aktif', sectionGreen),
      _ => ('Ditutup', sectionOrange),
    };
    final s = session?.summary;
    final progress = s == null || s.total == 0 ? 0.0 : s.recorded / s.total;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onOpen(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .35)),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    child: Icon(
                      type == 'PAGI'
                          ? Icons.wb_sunny_outlined
                          : Icons.mosque_outlined,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type == 'PAGI' ? 'Pagi' : 'Zuhur',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ColorPill(status, color: statusColor),
              const SizedBox(height: 10),
              Text(
                s == null
                    ? 'Ketuk untuk membuka'
                    : '${s.recorded}/${s.total} tercatat',
                style: const TextStyle(fontSize: 11, color: navy),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: color.withValues(alpha: .12),
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeacherWeeklySection extends StatelessWidget {
  const TeacherWeeklySection({
    super.key,
    required this.week,
    required this.loading,
    required this.onOpen,
    required this.onRetry,
    this.error,
  });
  final RecapPage? week;
  final bool loading;
  final VoidCallback onOpen, onRetry;
  final String? error;
  @override
  Widget build(BuildContext context) {
    if (error != null) return LoadErrorView(message: error!, onRetry: onRetry);
    final week = this.week;
    if (week == null) {
      return loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : const Text('Ringkasan belum tersedia.');
    }
    final s = week.summary;
    final rate = s.rate;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onOpen(),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sectionGreen.withValues(alpha: .3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: rate ?? 0,
                          strokeWidth: 7,
                          backgroundColor: sectionGreen.withValues(alpha: .12),
                          color: sectionGreen,
                        ),
                        Center(
                          child: Text(
                            rate == null
                                ? '-'
                                : '${(rate * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: sectionGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tingkat kehadiran',
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${week.total} siswa • ${week.sessionCount} sesi',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: muted),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, e) in [
                    ('HADIR', s.present),
                    ('TERLAMBAT', s.late),
                    ('IZIN', s.permit + s.sick),
                    ('ALFA', s.absent),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AttendanceCountTile(status: e.$1, count: e.$2),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeacherBaseMenu extends StatelessWidget {
  const TeacherBaseMenu({
    super.key,
    required this.onAttendance,
    required this.onRecap,
    required this.onReport,
  });
  final VoidCallback onAttendance, onRecap, onReport;
  @override
  Widget build(BuildContext context) => SchoolMenuGrid(
    items: [
      SchoolMenuItem(
        'Sesi Presensi',
        Icons.qr_code_2,
        schoolBlue,
        onAttendance,
      ),
      SchoolMenuItem(
        'Input Manual',
        Icons.edit_note,
        schoolOrange,
        onAttendance,
      ),
      SchoolMenuItem(
        'Rekap Kehadiran',
        Icons.bar_chart_rounded,
        schoolPurple,
        onRecap,
      ),
      SchoolMenuItem(
        'Lapor Pelanggaran',
        Icons.gavel_outlined,
        schoolRed,
        onReport,
      ),
    ],
  );
}

class TeacherFeatureMenu extends StatelessWidget {
  const TeacherFeatureMenu({
    super.key,
    required this.capabilities,
    required this.onOpen,
  });
  final AccountCapabilities capabilities;
  final void Function(TeacherFeature) onOpen;
  @override
  Widget build(BuildContext context) {
    final entries = <SchoolMenuItem>[
      if (capabilities.isBk) ...[
        SchoolMenuItem(
          'Penanganan Siswa',
          Icons.support_agent_outlined,
          schoolPurple,
          () => onOpen(TeacherFeature.caseManagement),
        ),
        SchoolMenuItem(
          'Rencana Konseling',
          Icons.event_note_outlined,
          schoolPurple,
          () => onOpen(TeacherFeature.counselingPlans),
        ),
      ],
      if (capabilities.isHomeroom)
        SchoolMenuItem(
          'Kelas Binaan',
          Icons.groups_outlined,
          schoolBlue,
          () => onOpen(TeacherFeature.homeroomCases),
        ),
      if (capabilities.isCoach)
        SchoolMenuItem(
          'Ekskul Binaan',
          Icons.emoji_events_outlined,
          schoolGreen,
          () => onOpen(TeacherFeature.extracurricular),
        ),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const SchoolSectionTitle(
          'Tugas dan Pendampingan',
          icon: Icons.work_outline,
          color: schoolPurple,
        ),
        SchoolMenuGrid(items: entries),
      ],
    );
  }
}
