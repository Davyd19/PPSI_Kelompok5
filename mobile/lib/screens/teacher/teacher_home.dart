import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../network/attendance_recap_api.dart';
import '../../network/auth_api.dart';
import '../../network/school_attendance_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';

const _red = Color(0xFFC62828);

/// Beranda peran Guru: sapaan, status presensi hari ini, menu cepat,
/// dan ringkasan kehadiran 7 hari terakhir.
class TeacherHome extends StatefulWidget {
  const TeacherHome({
    super.key,
    required this.api,
    required this.name,
    required this.onSchoolAttendance,
    required this.onAttendanceRecap,
    required this.onUnavailable,
    this.onViolationReport,
    this.assignments = const [],
    this.onPembina,
    this.primaryRole = 'GURU',
  });

  final List<String> assignments;
  final String primaryRole;
  final VoidCallback? onPembina;
  final AuthApi api;
  final String name;
  final Future<void> Function() onSchoolAttendance, onAttendanceRecap;
  final void Function(String feature) onUnavailable;
  final Future<void> Function()? onViolationReport;

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  late final _sessions = SchoolAttendanceApi(widget.api);
  late final _recap = AttendanceRecapApi(widget.api);
  SchoolDay? _day;
  RecapPage? _week;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = await Future.wait<Object?>([
      _sessions.today().then<Object?>((v) => v, onError: (_) => null),
      _recap
          .recap(
            RecapFilter(
              start: today.subtract(const Duration(days: 6)),
              end: today,
            ),
          )
          .then<Object?>((v) => v, onError: (_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      _day = results[0] as SchoolDay?;
      _week = results[1] as RecapPage?;
      _loading = false;
    });
  }

  Future<void> _go(Future<void> Function() open) async {
    await open();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _hero(),
            if (widget.assignments.isNotEmpty) ...[
              _title('Tugas Tambahan', Icons.work_outline, sectionBlue),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final duty in widget.assignments)
                    ActionChip(
                      label: Text(switch (duty) {
                        'PEMBINA_EKSTRAKURIKULER' => 'Pembina Ekstrakurikuler',
                        'WALI_KELAS' => 'Wali Kelas',
                        'GURU_BK' => 'Guru BK',
                        _ => duty,
                      }),
                      onPressed: duty == 'PEMBINA_EKSTRAKURIKULER'
                          ? widget.onPembina
                          : () => widget.onUnavailable(
                              duty == 'WALI_KELAS'
                                  ? 'Kelas Binaan'
                                  : 'Penanganan Siswa',
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (widget.primaryRole == 'GURU_BK') ...[
              const SizedBox(height: 16),
              const SchoolSectionTitle(
                'Pendampingan Siswa',
                icon: Icons.support_agent_outlined,
                color: schoolPurple,
              ),
              SchoolCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => widget.onUnavailable('Penanganan Siswa'),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Penanganan'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          widget.onUnavailable('Rencana Konseling'),
                      icon: const Icon(Icons.event_note_outlined),
                      label: const Text('Rencana Konseling'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            _title('Presensi Hari Ini', Icons.today_outlined, sectionBlue),
            _todaySessions(),
            const SizedBox(height: 18),
            _title('Menu', Icons.apps_rounded, sectionPurple),
            _menu(),
            const SizedBox(height: 18),
            _title(
              'Kehadiran 7 Hari Terakhir',
              Icons.insights_outlined,
              sectionGreen,
            ),
            _weekly(),
          ],
        ),
      ),
    ),
  );

  Widget _title(String text, IconData icon, Color color) =>
      SchoolSectionTitle(text, icon: icon, color: color);
  Widget _hero() => SchoolGreeting(
    name: widget.name,
    first: (
      icon: Icons.co_present_outlined,
      value: widget.primaryRole == 'GURU_BK' ? 'Guru BK' : 'Guru',
      label: 'Peran aktif',
    ),
    second: (
      icon: Icons.fact_check_outlined,
      value: '${_day?.sessions.where((s) => s.isActive).length ?? 0} sesi',
      label: 'Aktif hari ini',
    ),
  );

  Widget _todaySessions() {
    if (_loading && _day == null) {
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
    final session = _day?.session(type);
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
        onTap: () => _go(widget.onSchoolAttendance),
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

  // ---------- menu ----------
  Widget _menu() {
    final items = [
      (
        'Sesi Presensi',
        Icons.qr_code_2,
        sectionBlue,
        () => _go(widget.onSchoolAttendance),
      ),
      (
        'Input Manual',
        Icons.edit_note,
        sectionOrange,
        () => _go(widget.onSchoolAttendance),
      ),
      (
        'Rekap Kehadiran',
        Icons.bar_chart_rounded,
        sectionPurple,
        () => _go(widget.onAttendanceRecap),
      ),
      (
        'Lapor Pelanggaran',
        Icons.gavel_outlined,
        _red,
        () async => widget.onViolationReport == null
            ? widget.onUnavailable('Lapor Pelanggaran')
            : _go(widget.onViolationReport!),
      ),
    ];
    return GridView(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.textScalerOf(context).scale(11) > 13 ? 2 : 4,
        mainAxisExtent:
            112 *
            (MediaQuery.textScalerOf(context).scale(11) / 11).clamp(1, 1.6),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (label, icon, color, onTap) in items)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: .25)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: .3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11,
                        color: navy,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- 7 hari ----------
  Widget _weekly() {
    final week = _week;
    if (week == null) {
      return _loading
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
        onTap: () => _go(widget.onAttendanceRecap),
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
