import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../network/attendance_recap_api.dart';
import '../../network/auth_api.dart';
import '../../network/school_attendance_api.dart';
import '../../widgets/attendance_widgets.dart';
import '../../app/account_capabilities.dart';
import 'teacher_home_sections.dart';

/// Beranda peran Guru: sapaan, status presensi hari ini, menu cepat,
/// dan ringkasan kehadiran 7 hari terakhir.
class TeacherHome extends StatefulWidget {
  const TeacherHome({
    super.key,
    required this.api,
    required this.name,
    required this.onSchoolAttendance,
    required this.onAttendanceRecap,
    required this.onOpenFeature,
    required this.capabilities,
    required this.onViolationReport,
    this.primaryRole = 'GURU',
  });

  final AccountCapabilities capabilities;
  final String primaryRole;
  final AuthApi api;
  final String name;
  final Future<void> Function() onSchoolAttendance, onAttendanceRecap;
  final void Function(TeacherFeature feature) onOpenFeature;
  final Future<void> Function() onViolationReport;

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  late final _sessions = SchoolAttendanceApi(widget.api);
  late final _recap = AttendanceRecapApi(widget.api);
  SchoolDay? _day;
  RecapPage? _week;
  bool _loading = true;
  String? _sessionError, _weekError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String? sessionError, weekError;
    final results = await Future.wait<Object?>([
      _sessions.today().then<Object?>(
        (v) => v,
        onError: (Object e) {
          sessionError = e.toString();
          return null;
        },
      ),
      _recap
          .recap(
            RecapFilter(
              start: today.subtract(const Duration(days: 6)),
              end: today,
            ),
          )
          .then<Object?>(
            (v) => v,
            onError: (Object e) {
              weekError = e.toString();
              return null;
            },
          ),
    ]);
    if (!mounted) return;
    setState(() {
      _day = results[0] as SchoolDay?;
      _week = results[1] as RecapPage?;
      _sessionError = sessionError;
      _weekError = weekError;
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
            TeacherFeatureMenu(
              capabilities: widget.capabilities,
              onOpen: widget.onOpenFeature,
            ),
            const SizedBox(height: 18),
            _title('Presensi Hari Ini', Icons.today_outlined, sectionBlue),
            TeacherAttendanceSection(
              day: _day,
              loading: _loading,
              error: _sessionError,
              onRetry: _load,
              onOpen: () => _go(widget.onSchoolAttendance),
            ),
            const SizedBox(height: 18),
            _title('Menu', Icons.apps_rounded, sectionPurple),
            TeacherBaseMenu(
              onAttendance: () => _go(widget.onSchoolAttendance),
              onRecap: () => _go(widget.onAttendanceRecap),
              onReport: () => _go(widget.onViolationReport),
            ),
            const SizedBox(height: 18),
            _title(
              'Kehadiran 7 Hari Terakhir',
              Icons.insights_outlined,
              sectionGreen,
            ),
            TeacherWeeklySection(
              week: _week,
              loading: _loading,
              error: _weekError,
              onRetry: _load,
              onOpen: () => _go(widget.onAttendanceRecap),
            ),
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
      value: _sessionError != null
          ? 'Gagal dimuat'
          : _day == null
          ? 'Memuat...'
          : '${_day!.sessions.where((s) => s.isActive).length} sesi',
      label: 'Aktif hari ini',
    ),
  );
}
