part of 'attendance_recap_screen.dart';

/// Tahap 2: hasil rekap sesuai filter.
class _RecapResultPage extends StatefulWidget {
  const _RecapResultPage({
    required this.api,
    required this.filter,
    required this.className,
  });
  final AttendanceRecapApi api;
  final RecapFilter filter;
  final String className;

  @override
  State<_RecapResultPage> createState() => _RecapResultPageState();
}

class _RecapResultPageState extends State<_RecapResultPage> {
  late RecapFilter _filter = widget.filter;
  final _search = TextEditingController();
  Timer? _debounce;

  RecapPage? _page;
  final _rows = <RecapRow>[];
  bool _loading = true, _loadingMore = false;
  Object? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final ticket = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.recap(_filter);
      if (!mounted || ticket != _request) return;
      setState(() {
        _page = page;
        _rows
          ..clear()
          ..addAll(page.rows);
      });
    } catch (error) {
      if (mounted && ticket == _request) setState(() => _error = error);
    } finally {
      if (mounted && ticket == _request) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final page = _page;
    if (page == null || !page.hasMore || _loadingMore) return;
    final ticket = _request;
    setState(() => _loadingMore = true);
    try {
      final next = await widget.api.recap(_filter, page: page.page + 1);
      if (!mounted || ticket != _request) return;
      setState(() {
        _page = next;
        _rows.addAll(next.rows);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _filter = widget.filter.withQuery(value);
      _reload();
    });
  }

  void _openHistory(RecapRow row) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _HistorySheet(
      api: widget.api,
      row: row,
      filter: _filter,
      // Rekap kehadiran diperbarui setiap kali ada presensi yang diubah.
      onChanged: _reload,
    ),
  );

  String get _typeLabel => switch (widget.filter.type) {
    'PAGI' => 'Pagi',
    'ZUHUR' => 'Zuhur',
    _ => 'Semua sesi',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: navy,
      title: Text(widget.className),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: _loading ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _reload,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [_filterBar(), const SizedBox(height: 10), ..._content()],
          ),
        ),
      ),
    ),
  );

  /// Ringkasan filter yang dipakai; ketuk untuk kembali ke tahap 1.
  Widget _filterBar() => Material(
    color: attendanceSoft,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_outlined, size: 18, color: navy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_periodText(widget.filter)} • $_typeLabel',
                style: const TextStyle(fontSize: 12, color: navy),
              ),
            ),
            const Text(
              'Ubah',
              style: TextStyle(
                color: attendanceTeal,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.chevron_right, color: attendanceTeal),
          ],
        ),
      ),
    ),
  );

  List<Widget> _content() {
    final page = _page;
    if (_loading && page == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null && page == null) {
      return [
        const SizedBox(height: 24),
        Text('$_error', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Center(
          child: FilledButton(
            onPressed: _reload,
            child: const Text('Coba lagi'),
          ),
        ),
      ];
    }
    if (page == null) return const [];
    return [
      _SummaryCard(page: page),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: _onSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search),
          hintText: 'Cari nama / NIS',
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    _onSearch('');
                  },
                ),
        ),
      ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Daftar Siswa',
                style: TextStyle(color: navy, fontWeight: FontWeight.w700),
              ),
            ),
            ColorPill('${page.total} siswa', color: sectionPurple),
          ],
        ),
      ),
      if (_rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada data.', textAlign: TextAlign.center),
        )
      else
        for (final (i, r) in _rows.indexed)
          _StudentTile(
            index: i + 1,
            row: r,
            showClass: widget.filter.classId == null,
            onTap: () => _openHistory(r),
          ),
      if (page.hasMore)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(
            onPressed: _loadingMore ? null : _loadMore,
            child: Text(
              _loadingMore
                  ? 'Memuat...'
                  : 'Muat lebih banyak (${_rows.length}/${page.total})',
            ),
          ),
        ),
    ];
  }
}

Color _rateColor(double r) => r >= .9
    ? attendanceStatusColors['HADIR']!
    : r >= .75
    ? attendanceStatusColors['TERLAMBAT']!
    : attendanceStatusColors['ALFA']!;

/// Satu kartu ringkas: persentase kehadiran + 4 angka utama.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.page});
  final RecapPage page;

  @override
  Widget build(BuildContext context) {
    final s = page.summary;
    final rate = s.rate;
    Widget stat(String label, int value, String status) => Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: attendanceStatusColors[status],
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: attendanceTeal.withValues(alpha: .25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: rate ?? 0,
                      strokeWidth: 7,
                      backgroundColor: attendanceSoft,
                      color: rate == null ? muted : _rateColor(rate),
                    ),
                    Center(
                      child: Text(
                        rate == null
                            ? '-'
                            : '${(rate * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: navy,
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
                      'Tingkat Kehadiran',
                      style: TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${page.total} siswa • ${page.sessionCount} sesi',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    if (s.pending > 0)
                      Text(
                        '${s.pending} belum diisi (tidak dihitung)',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              stat('Hadir', s.present, 'HADIR'),
              stat('Terlambat', s.late, 'TERLAMBAT'),
              stat('Izin/Sakit', s.permit + s.sick, 'IZIN'),
              stat('Alfa', s.absent, 'ALFA'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris siswa yang ringkas; detail lengkap ada di riwayat.
class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.index,
    required this.row,
    required this.showClass,
    required this.onTap,
  });
  final int index;
  final RecapRow row;
  final bool showClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = row.counts;
    final rate = c.rate;
    final color = rate == null ? muted : _rateColor(rate);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: .3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(width: 4, height: 64, color: color),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 14,
              backgroundColor: attendanceSoft,
              child: Text(
                '$index',
                style: const TextStyle(fontSize: 11, color: navy),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (showClass) row.classroom,
                      'H ${c.present}',
                      'T ${c.late}',
                      'I/S ${c.permit + c.sick}',
                      'A ${c.absent}',
                    ].join(' • '),
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ColorPill(
                rate == null ? '-' : '${(rate * 100).toStringAsFixed(0)}%',
                color: color,
              ),
            ),
            const Icon(Icons.chevron_right, color: muted),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Tahap 3: riwayat presensi seorang siswa per sesi pada periode filter.
/// Use case "Mengubah Presensi": ketuk satu sesi untuk mengoreksi statusnya.
class _HistorySheet extends StatefulWidget {
  const _HistorySheet({
    required this.api,
    required this.row,
    required this.filter,
    required this.onChanged,
  });
  final AttendanceRecapApi api;
  final RecapRow row;
  final RecapFilter filter;
  final VoidCallback onChanged;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late Future<List<HistoryEntry>> _items = _load();
  String? _notice;

  Future<List<HistoryEntry>> _load() =>
      widget.api.history(widget.row.studentId, widget.filter);

  Future<void> _edit(HistoryEntry entry) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _CorrectionSheet(
        api: widget.api,
        studentId: widget.row.studentId,
        studentName: widget.row.name,
        entry: entry,
      ),
    );
    if (result == null || !mounted) return;
    // Notifikasi berhasil, lalu rekap kehadiran diperbarui.
    setState(() {
      _notice =
          'Presensi ${formatYmd(entry.date)} berhasil diperbarui menjadi '
          '${attendanceStatusLabels[result] ?? result}.';
      _items = _load();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FutureBuilder<List<HistoryEntry>>(
          future: _items,
          builder: (context, snap) {
            final items = snap.data;
            int count(String s) =>
                items?.where((e) => e.status == s).length ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(row.name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${row.classroom} • NIS ${row.nis ?? '-'} • NISN ${row.nisn}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in const [
                      'HADIR',
                      'TERLAMBAT',
                      'IZIN',
                      'SAKIT',
                      'ALFA',
                    ])
                      AttendanceCountTile(status: s, count: count(s)),
                  ],
                ),
                if (_notice != null) ...[
                  const SizedBox(height: 10),
                  _Banner(
                    _notice!,
                    onClose: () => setState(() => _notice = null),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Ketuk sesi untuk mengubah presensi.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 4),
                Flexible(child: _list(snap)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list(AsyncSnapshot<List<HistoryEntry>> snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snap.hasError) return Text('${snap.error}');
    final items = snap.data!;
    if (items.isEmpty) return const Text('Belum ada sesi pada periode ini.');
    return ListView.separated(
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = items[i];
        final how = switch (e.method) {
          'QR' => 'Pindai QR',
          'MANUAL' => 'Manual',
          _ => 'Belum tercatat',
        };
        final lines = [
          '$how • ${formatHhmm(e.time)}',
          if (e.corrected)
            'Diubah oleh ${e.recordedBy ?? '-'} '
                '(awal: ${attendanceStatusLabels[e.originalStatus ?? 'BELUM_DIISI']})',
          if (e.note != null) 'Alasan: ${e.note}',
        ];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: e.editable,
          onTap: e.editable ? () => _edit(e) : null,
          leading: Icon(
            e.type == 'PAGI' ? Icons.wb_sunny_outlined : Icons.mosque_outlined,
            color: attendanceTeal,
          ),
          title: Text(
            '${formatYmd(e.date)} • ${e.type == 'PAGI' ? 'Pagi' : 'Zuhur'}',
          ),
          subtitle: Text(
            lines.join('\n'),
            style: TextStyle(
              fontSize: 11,
              color: e.corrected ? sectionOrange : null,
            ),
          ),
          isThreeLine: lines.length > 1,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AttendanceStatusBadge(e.status),
              if (e.editable)
                const Icon(Icons.edit_outlined, size: 18, color: muted),
            ],
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {required this.onClose});
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final green = attendanceStatusColors['HADIR']!;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
      decoration: BoxDecoration(
        color: green.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: green.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: green, fontSize: 12)),
          ),
          IconButton(
            tooltip: 'Tutup',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close, size: 18, color: green),
          ),
        ],
      ),
    );
  }
}

/// Formulir "Ubah Presensi": pilih status baru + alasan (wajib, berjejak).
/// Mengembalikan status baru bila berhasil disimpan.
class _CorrectionSheet extends StatefulWidget {
  const _CorrectionSheet({
    required this.api,
    required this.studentId,
    required this.studentName,
    required this.entry,
  });
  final AttendanceRecapApi api;
  final int studentId;
  final String studentName;
  final HistoryEntry entry;

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  final _reason = TextEditingController();
  String? _status, _error;
  bool _saving = false;

  static const _quickReasons = [
    'Titip absen',
    'Scan di luar sekolah',
    'Ada surat izin',
    'Ada surat sakit',
    'Salah input',
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _valid =>
      _status != null &&
      _status != widget.entry.status &&
      _reason.text.trim().length >= 5;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.correct(
        sessionId: widget.entry.sessionId,
        studentId: widget.studentId,
        status: _status!,
        reason: _reason.text,
      );
      if (mounted) Navigator.of(context).pop(_status);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ubah Presensi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${widget.studentName} • ${formatYmd(e.date)} • '
              '${e.type == 'PAGI' ? 'Pagi' : 'Zuhur'}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Status saat ini  '),
                AttendanceStatusBadge(e.status),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Status baru',
              style: TextStyle(color: navy, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: s, value: label)
                    in manualAttendanceStatuses.entries)
                  if (s != e.status)
                    ChoiceChip(
                      label: Text(label),
                      selected: _status == s,
                      showCheckmark: false,
                      selectedColor: attendanceStatusColors[s],
                      labelStyle: TextStyle(
                        color: _status == s
                            ? Colors.white
                            : attendanceStatusColors[s],
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: attendanceStatusColors[s]!.withValues(alpha: .4),
                      ),
                      onSelected: (_) => setState(() => _status = s),
                    ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Alasan perubahan',
              style: TextStyle(color: navy, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in _quickReasons)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(r, style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _reason.text = r),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              maxLength: 191,
              minLines: 2,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Tulis alasan (min. 5 karakter)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: attendanceStatusColors['ALFA']),
                ),
              ),
            const Text(
              'Perubahan dicatat beserta nama Anda, waktu, dan status sebelumnya.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: attendanceTeal,
              ),
              onPressed: _valid && !_saving ? _save : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}
