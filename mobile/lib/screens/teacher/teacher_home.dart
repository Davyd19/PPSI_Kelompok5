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
  });

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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
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

  Widget _title(String text, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  // ---------- sapaan ----------
  Widget _hero() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [navy, attendanceTeal, sectionBlue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .25),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -30,
          top: -30,
          child: _bubble(130, .08),
        ),
        Positioned(
          right: 40,
          bottom: -40,
          child: _bubble(90, .06),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_greeting,',
                      style: const TextStyle(
                        color: Color(0xFFD9E9FA),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatDateId(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _heroStat(
                    Icons.co_present_outlined,
                    'Guru',
                    'Peran aktif',
                  ),
                  const SizedBox(width: 10),
                  _heroStat(
                    Icons.qr_code_2,
                    _activeCount == null ? '-' : '$_activeCount sesi',
                    'Aktif hari ini',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  int? get _activeCount =>
      _day?.sessions.where((s) => s.isActive).length;

  Widget _bubble(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  Widget _heroStat(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFD9E9FA),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ---------- presensi hari ini ----------
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
            gradient: LinearGradient(
              colors: [color.withValues(alpha: .12), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
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
                s == null ? 'Ketuk untuk membuka' : '${s.recorded}/${s.total} tercatat',
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
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: .78,
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
