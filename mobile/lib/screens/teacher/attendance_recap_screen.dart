import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/attendance_recap_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';

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

enum _Period { week, month, thisMonth, custom }

class _AttendanceRecapScreenState extends State<AttendanceRecapScreen> {
  List<RecapClass>? _classes;
  Object? _classError;

  int? _classId;
  String? _type;
  _Period _period = _Period.month;
  late DateTime _start, _end;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _start = _today;
    _setPeriod(_Period.month);
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

  void _setPeriod(_Period p) {
    final t = _today;
    _period = p;
    _end = t;
    _start = switch (p) {
      _Period.week => t.subtract(const Duration(days: 6)),
      _Period.month => t.subtract(const Duration(days: 29)),
      _Period.thisMonth => DateTime(t.year, t.month),
      _Period.custom => _start,
    };
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_today.year - 2),
      lastDate: _today,
      initialDateRange: DateTimeRange(start: _start, end: _end),
      helpText: 'Pilih periode rekap',
      saveText: 'Terapkan',
    );
    if (range == null || !mounted) return;
    if (range.duration.inDays > 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Periode maksimal 1 tahun.')),
      );
      return;
    }
    setState(() {
      _period = _Period.custom;
      _start = range.start;
      _end = range.end;
    });
  }

  void _show() {
    final className = _classId == null
        ? 'Semua kelas'
        : _classes!.firstWhere((c) => c.id == _classId).name;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RecapResultPage(
          api: widget.api,
          filter: RecapFilter(
            start: _start,
            end: _end,
            classId: _classId,
            type: _type,
          ),
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
      title: const Text('Rekap Kehadiran'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (p, label) in const [
                        (_Period.week, '7 hari'),
                        (_Period.month, '30 hari'),
                        (_Period.thisMonth, 'Bulan ini'),
                      ])
                        _choice(
                          label,
                          _period == p,
                          sectionOrange,
                          () => setState(() => _setPeriod(p)),
                        ),
                      _choice(
                        'Pilih tanggal',
                        _period == _Period.custom,
                        sectionOrange,
                        _pickRange,
                        icon: Icons.edit_calendar_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${formatDateId(_start)} – ${formatDateId(_end)}',
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w600,
                    ),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _choice(
          'Semua kelas',
          _classId == null,
          sectionBlue,
          () => setState(() => _classId = null),
        ),
        for (final c in classes)
          _choice(
            c.name,
            _classId == c.id,
            sectionBlue,
            () => setState(() => _classId = c.id),
          ),
      ],
    );
  }

  Widget _choice(
    String label,
    bool selected,
    Color color,
    VoidCallback onTap, {
    IconData? icon,
  }) => ChoiceChip(
    label: Text(label),
    avatar: icon == null
        ? null
        : Icon(icon, size: 16, color: selected ? Colors.white : color),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    selectedColor: color,
    backgroundColor: color.withValues(alpha: .07),
    side: BorderSide(color: color.withValues(alpha: .35)),
    labelStyle: TextStyle(
      color: selected ? Colors.white : color,
      fontWeight: FontWeight.w600,
    ),
  );
}
