import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/attendance_recap_api.dart';
import '../../network/school_attendance_api.dart'
    show attendanceStatusLabels, manualAttendanceStatuses;
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';
import '../../widgets/school_ui.dart';

part 'attendance_recap_result.dart';

/// Use case Guru: "Melihat Rekap Kehadiran".
/// Alur bertahap:
/// 1. Halaman filter: pilih kelas -> periode -> jenis sesi -> "Lihat Rekap".
/// 2. Halaman hasil: ringkasan singkat + daftar siswa (bisa dicari).
/// 3. Ketuk siswa -> riwayat presensi per sesi.
class AttendanceRecapScreen extends StatefulWidget {
  const AttendanceRecapScreen({super.key, required this.api});
  final AttendanceRecapApi api;

  @override
  State<AttendanceRecapScreen> createState() => _AttendanceRecapScreenState();
}

enum _Period {
  today('Hari ini'),
  week('7 hari terakhir'),
  month('30 hari terakhir'),
  all('Semua');

  const _Period(this.label);
  final String label;
}

/// Teks periode untuk ditampilkan, mis. "Semua periode" atau "1 – 7 Nov 2026".
String _periodText(RecapFilter f) => f.all
    ? 'Semua periode'
    : f.start == f.end
    ? formatDateId(f.start)
    : '${formatDateId(f.start)} – ${formatDateId(f.end)}';

class _AttendanceRecapScreenState extends State<AttendanceRecapScreen> {
  List<RecapClass>? _classes;
  Object? _classError;

  int? _classId;
  String? _type;
  _Period _period = _Period.month;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  RecapFilter get _filter {
    final t = _today;
    return RecapFilter(
      start: switch (_period) {
        _Period.today || _Period.all => t,
        _Period.week => t.subtract(const Duration(days: 6)),
        _Period.month => t.subtract(const Duration(days: 29)),
      },
      end: t,
      all: _period == _Period.all,
      classId: _classId,
      type: _type,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _classError = null);
    try {
      final c = await widget.api.classes();
      if (mounted) setState(() => _classes = c);
    } catch (e) {
      if (mounted) setState(() => _classError = e);
    }
  }

  void _show() {
    final className = _classId == null
        ? 'Semua kelas'
        : _classes!.firstWhere((c) => c.id == _classId).name;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RecapResultPage(
          api: widget.api,
          filter: _filter,
          className: className,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: const SchoolPageTitle(title: 'Rekap Kehadiran'),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: attendanceTeal,
        ),
        onPressed: _classes == null ? null : _show,
        icon: const Icon(Icons.bar_chart_rounded),
        label: const Text('Lihat Rekap'),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            SectionCard(
              title: '1. Kelas',
              icon: Icons.groups_outlined,
              color: sectionBlue,
              child: _classPicker(),
            ),
            SectionCard(
              title: '2. Periode',
              icon: Icons.date_range,
              color: sectionOrange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<_Period>(
                    initialValue: _period,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.event_note_outlined),
                    ),
                    items: [
                      for (final p in _Period.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (p) => setState(() => _period = p!),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _periodText(_filter),
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: '3. Sesi',
              icon: Icons.schedule,
              color: sectionGreen,
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String?>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: null, label: Text('Semua')),
                    ButtonSegment(
                      value: 'PAGI',
                      icon: Icon(Icons.wb_sunny_outlined),
                      label: Text('Pagi'),
                    ),
                    ButtonSegment(
                      value: 'ZUHUR',
                      icon: Icon(Icons.mosque_outlined),
                      label: Text('Zuhur'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (v) => setState(() => _type = v.first),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _classPicker() {
    final classes = _classes;
    if (_classError != null) {
      return Row(
        children: [
          const Expanded(child: Text('Gagal memuat kelas.')),
          TextButton(onPressed: _loadClasses, child: const Text('Coba lagi')),
        ],
      );
    }
    if (classes == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return DropdownButtonFormField<int?>(
      initialValue: _classId,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.class_outlined),
      ),
      items: [
        const DropdownMenuItem<int?>(child: Text('Semua kelas')),
        for (final c in classes)
          DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
      ],
      onChanged: (v) => setState(() => _classId = v),
    );
  }
}
