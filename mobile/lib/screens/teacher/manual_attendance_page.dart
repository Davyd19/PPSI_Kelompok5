import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';

import '../../network/school_attendance_api.dart';
import '../../theme.dart';
import '../../widgets/attendance_widgets.dart';

const _picked = Color(0xFFF2F8F4);

enum _Filter { all, pending, recorded }

/// Input manual berjejak per kelas:
/// 1) pilih kelas -> 2) isi presensi & alasan di tabel -> 3) alasan umum,
/// tinjau, simpan. Siswa yang sudah tercatat (QR/manual) tampil terkunci
/// beserta jejaknya.
class ManualAttendancePage extends StatefulWidget {
  const ManualAttendancePage({
    super.key,
    required this.api,
    required this.session,
  });
  final SchoolAttendanceApi api;
  final SchoolSession session;

  @override
  State<ManualAttendancePage> createState() => _ManualAttendancePageState();
}

class _ManualAttendancePageState extends State<ManualAttendancePage> {
  static const _quickReasons = [
    'QR gagal terbaca',
    'HP siswa rusak/habis baterai',
    'Siswa tidak membawa HP',
    'Surat izin dari orang tua',
    'Tidak hadir tanpa keterangan',
  ];

  List<ClassroomOption>? _classes;
  ClassroomOption? _class;
  List<RosterStudent>? _students;
  final _status = <int, String>{};
  final _reasons = <int, TextEditingController>{};
  final _common = TextEditingController();
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  bool _showErrors = false, _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    for (final c in _reasons.values) {
      c.dispose();
    }
    _common.dispose();
    _search.dispose();
    super.dispose();
  }

  // ---------- data ----------

  Future<void> _loadClasses() async {
    setState(() => _error = null);
    try {
      final classes = await widget.api.classes(widget.session.id);
      if (mounted) setState(() => _classes = classes);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _loadStudents() async {
    final classroom = _class;
    if (classroom == null) return;
    setState(() => _error = null);
    try {
      final rows = await widget.api.students(
        widget.session.id,
        classId: classroom.id,
      );
      if (!mounted) return;
      setState(() {
        _students = rows;
        // Buang isian siswa yang ternyata sudah tercatat (mis. baru scan QR).
        final pending = {
          for (final s in rows)
            if (s.isPending) s.id,
        };
        _status.removeWhere((id, _) => !pending.contains(id));
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  TextEditingController _reasonOf(int id) =>
      _reasons.putIfAbsent(id, TextEditingController.new);

  String _effectiveReason(int id) {
    final own = _reasons[id]?.text.trim() ?? '';
    return own.isNotEmpty ? own : _common.text.trim();
  }

  bool _reasonInvalid(int id) =>
      _status.containsKey(id) && _effectiveReason(id).length < 5;

  bool get _dirty =>
      _status.isNotEmpty ||
      _reasons.values.any((c) => c.text.trim().isNotEmpty);

  void _resetInputs() {
    _status.clear();
    for (final c in _reasons.values) {
      c.clear();
    }
    _showErrors = false;
  }

  // ---------- navigasi ----------

  void _pickClass(ClassroomOption classroom) {
    setState(() {
      _class = classroom;
      _students = null;
      _filter = _Filter.all;
      _search.clear();
      _resetInputs();
    });
    _loadStudents();
  }

  Future<void> _backToClasses() async {
    if (_dirty && !await _confirmDiscard()) return;
    setState(() {
      _class = null;
      _students = null;
      _resetInputs();
    });
    _loadClasses();
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => SchoolDialog(
          title: const Text('Buang isian?'),
          content: Text(
            '${_status.length} presensi yang belum disimpan akan hilang.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buang'),
            ),
          ],
        ),
      ) ==
      true;

  // ---------- aksi ----------

  void _fillPending(String status) => setState(() {
    for (final s in _students ?? const <RosterStudent>[]) {
      if (s.isPending) _status[s.id] = status;
    }
  });

  Future<void> _review() async {
    final students = _students ?? const <RosterStudent>[];
    if (_status.isEmpty) {
      _toast('Pilih presensi minimal satu siswa.');
      return;
    }
    if (_status.keys.any(_reasonInvalid)) {
      setState(() => _showErrors = true);
      _toast(
        'Lengkapi alasan (min. 5 karakter) pada baris bertanda merah, '
        'atau isi Alasan Umum.',
      );
      return;
    }
    final chosen = [
      for (final s in students)
        if (_status.containsKey(s.id)) s,
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => SchoolDialog(
        title: Text('Simpan ${chosen.length} presensi?'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.session.label} • Kelas ${_class!.name}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: chosen.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = chosen[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.name),
                      subtitle: Text('Alasan: ${_effectiveReason(s.id)}'),
                      trailing: AttendanceStatusBadge(_status[s.id]!),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Data yang sudah disimpan tidak dapat diubah dari layar ini '
                '(gunakan fitur Ubah Presensi).',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Periksa lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok == true) await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final count = _status.length;
      await widget.api.manualBatch(
        widget.session.id,
        classId: _class!.id,
        commonReason: _common.text,
        entries: {
          for (final e in _status.entries)
            e.key: (status: e.value, reason: _reasons[e.key]?.text ?? ''),
        },
      );
      if (!mounted) return;
      setState(_resetInputs);
      _toast('$count presensi kelas ${_class!.name} tersimpan.');
      await _loadStudents();
    } catch (error) {
      if (mounted) _toast(error);
      await _loadStudents();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(Object message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message.toString())));

  // ---------- tampilan ----------

  @override
  Widget build(BuildContext context) {
    final classroom = _class;
    return PopScope(
      canPop: classroom == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToClasses();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: navy,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                classroom == null ? 'Input Manual' : 'Kelas ${classroom.name}',
              ),
              Text(
                widget.session.label,
                style: const TextStyle(fontSize: 11, color: attendanceTeal),
              ),
            ],
          ),
        ),
        body: classroom == null ? _classList() : _classView(classroom),
        bottomNavigationBar: classroom == null || _students == null
            ? null
            : _saveBar(),
      ),
    );
  }

  Widget _errorView(VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );

  // Tahap 1: pilih kelas.
  Widget _classList() {
    final classes = _classes;
    if (classes == null) {
      return _error == null ? const SchoolLoading() : _errorView(_loadClasses);
    }
    return RefreshIndicator(
      onRefresh: _loadClasses,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Pilih Kelas',
            icon: Icons.groups_outlined,
            color: sectionBlue,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: classes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Tidak ada kelas aktif.'),
                  )
                : Column(
                    children: [
                      for (final (i, c) in classes.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(
                            c.name,
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('${c.total} siswa'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              c.pending == 0
                                  ? const ColorPill(
                                      'Lengkap',
                                      color: sectionGreen,
                                      icon: Icons.check,
                                    )
                                  : ColorPill(
                                      '${c.pending} belum',
                                      color: sectionOrange,
                                    ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => _pickClass(c),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Tahap 2 & 3.
  Widget _classView(ClassroomOption classroom) {
    final students = _students;
    if (students == null) {
      return _error == null ? const SchoolLoading() : _errorView(_loadStudents);
    }
    final query = _search.text.trim().toLowerCase();
    final visible = [
      for (final (i, s) in students.indexed)
        if ((_filter == _Filter.all ||
                (_filter == _Filter.pending) == s.isPending) &&
            (query.isEmpty ||
                s.name.toLowerCase().contains(query) ||
                s.nisn.contains(query) ||
                (s.nis ?? '').contains(query)))
          (i + 1, s),
    ];
    final pending = students.where((s) => s.isPending).length;
    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // Pencarian selalu di paling atas halaman.
          SchoolSearchField(
            hint: 'Cari nama / NIS / NISN',
            initialValue: _search.text,
            onChanged: (v) => setState(() => _search.text = v),
          ),
          const SizedBox(height: 12),
          _sessionInfo(classroom, students.length, pending),
          SectionCard(
            title: 'Ringkasan',
            icon: Icons.insights_outlined,
            color: sectionGreen,
            child: _summary(students),
          ),
          SectionCard(
            title: 'Daftar Siswa',
            icon: Icons.table_rows_outlined,
            color: sectionBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_Filter>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: _Filter.all,
                      label: Text('Semua ${students.length}'),
                    ),
                    ButtonSegment(
                      value: _Filter.pending,
                      label: Text('Belum $pending'),
                    ),
                    ButtonSegment(
                      value: _Filter.recorded,
                      label: Text('Tercatat ${students.length - pending}'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (v) => setState(() => _filter = v.first),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (pending > 0)
                      TextButton.icon(
                        onPressed: () => _fillPending('HADIR'),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Semua belum = Hadir'),
                      ),
                    if (_status.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(_resetInputs),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Reset isian'),
                      ),
                  ],
                ),
                _table(visible),
              ],
            ),
          ),
          SectionCard(
            title: 'Alasan Umum',
            icon: Icons.edit_note,
            color: sectionOrange,
            child: _commonReason(),
          ),
        ],
      ),
    );
  }

  Widget _sessionInfo(ClassroomOption classroom, int total, int pending) =>
      HeroHeader(
        icon: Icons.class_outlined,
        title: 'Kelas ${classroom.name}',
        subtitle: '$total siswa • $pending belum tercatat',
        trailing: IconButton(
          tooltip: 'Ganti kelas',
          onPressed: _backToClasses,
          icon: const Icon(Icons.swap_horiz, color: Colors.white),
        ),
      );

  Widget _summary(List<RosterStudent> students) {
    // Status tercatat + pilihan yang belum disimpan (pratinjau).
    final counts = <String, int>{};
    for (final s in students) {
      final key = s.isPending ? (_status[s.id] ?? 'BELUM_DIISI') : s.status;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final k in const [
          'HADIR',
          'TERLAMBAT',
          'IZIN',
          'SAKIT',
          'ALFA',
          'BELUM_DIISI',
        ])
          if (k != 'SAKIT' || (counts[k] ?? 0) > 0)
            AttendanceCountTile(status: k, count: counts[k] ?? 0),
      ],
    );
  }

  Widget _table(List<(int, RosterStudent)> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Tidak ada siswa yang sesuai.')),
      );
    }
    // Layar sempit: kolom detail (kelas, waktu, pencatat) digabung agar
    // tabel tidak perlu digeser jauh.
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        horizontalMargin: 4,
        headingRowHeight: 40,
        dataRowMinHeight: 64,
        dataRowMaxHeight: 80,
        headingRowColor: tableHeadingColor,
        headingTextStyle: tableHeadingStyle,
        columns: [
          const DataColumn(label: Text('No'), numeric: true),
          const DataColumn(label: Text('Siswa')),
          if (wide) const DataColumn(label: Text('Kelas')),
          const DataColumn(label: Text('Presensi')),
          const DataColumn(label: Text('Alasan')),
          if (wide) const DataColumn(label: Text('Dicatat')),
        ],
        rows: [
          for (final (no, s) in rows)
            DataRow(
              color: WidgetStatePropertyAll(
                _status.containsKey(s.id) ? _picked : zebra(no),
              ),
              cells: [
                DataCell(Text('$no')),
                DataCell(_studentCell(s, showClass: !wide)),
                if (wide) DataCell(Text(s.classroom)),
                DataCell(_statusCell(s, showTrace: !wide)),
                DataCell(_reasonCell(s)),
                if (wide) DataCell(_traceText(s)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _studentCell(RosterStudent s, {required bool showClass}) =>
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: navy, fontWeight: FontWeight.w600),
            ),
            Text(
              'NIS ${s.nis ?? '-'} • NISN ${s.nisn}',
              style: const TextStyle(fontSize: 10),
            ),
            if (showClass)
              Text(s.classroom, style: const TextStyle(fontSize: 10)),
          ],
        ),
      );

  Widget _statusCell(RosterStudent s, {required bool showTrace}) {
    if (!s.isPending) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttendanceStatusBadge(s.status),
          if (showTrace) ...[const SizedBox(height: 4), _traceText(s)],
        ],
      );
    }
    return DropdownButton<String>(
      value: _status[s.id],
      hint: const Text('Pilih', style: TextStyle(fontSize: 13)),
      isDense: true,
      onChanged: _saving
          ? null
          : (value) => setState(() {
              if (value == null) {
                _status.remove(s.id);
              } else {
                _status[s.id] = value;
              }
            }),
      items: [
        for (final e in classAttendanceOptions.entries)
          if (e.key != 'PENGECUALIAN_SAH' || widget.session.type == 'ZUHUR')
            DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value,
                style: TextStyle(color: attendanceStatusColors[e.key]),
              ),
            ),
      ],
    );
  }

  Widget _traceText(RosterStudent s) {
    if (s.isPending) {
      return const Text(
        'Belum tercatat',
        style: TextStyle(fontSize: 11, color: muted),
      );
    }
    final who = s.method == 'QR' ? 'QR' : 'Manual • ${s.recordedBy ?? '-'}';
    return Text(
      '$who • ${formatHhmm(s.recordedAt)}',
      style: const TextStyle(fontSize: 10, color: muted),
    );
  }

  Widget _reasonCell(RosterStudent s) {
    if (!s.isPending) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          s.method == 'QR' ? 'Pindai QR berhasil' : (s.note ?? '-'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: muted),
        ),
      );
    }
    final error = _showErrors && _reasonInvalid(s.id);
    return SizedBox(
      width: 180,
      child: TextField(
        controller: _reasonOf(s.id),
        enabled: !_saving,
        maxLength: 191,
        style: const TextStyle(fontSize: 12),
        onChanged: (_) {
          if (_showErrors) setState(() {});
        },
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: _common.text.trim().isEmpty
              ? 'Tulis alasan...'
              : 'Pakai alasan umum',
          errorText: error ? 'Wajib, min. 5 karakter' : null,
          errorStyle: const TextStyle(fontSize: 10),
        ),
      ),
    );
  }

  Widget _commonReason() => Column(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _common,
            maxLength: 191,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Untuk baris yang alasannya kosong',
              counterText: '',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in _quickReasons)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(r, style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _common.text = r),
                ),
            ],
          ),
        ],
      ),
    ],
  );

  // Bar bawah ringkas: hanya tombol simpan agar tabel tidak tertutup.
  Widget _saveBar() => SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE7EDF6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _status.isEmpty
                  ? 'Belum ada isian'
                  : '${_status.length} siswa siap disimpan',
              style: const TextStyle(fontSize: 12, color: navy),
            ),
          ),
          FilledButton.icon(
            onPressed: _saving || _status.isEmpty ? null : _review,
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: Text(_saving ? 'Menyimpan...' : 'Tinjau & Simpan'),
          ),
        ],
      ),
    ),
  );
}
