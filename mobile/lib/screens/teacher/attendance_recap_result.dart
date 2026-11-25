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
      _filter = RecapFilter(
        start: widget.filter.start,
        end: widget.filter.end,
        classId: widget.filter.classId,
        type: widget.filter.type,
        query: value,
      );
      _reload();
    });
  }

  void _openHistory(RecapRow row) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _HistorySheet(api: widget.api, row: row, filter: _filter),
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
                '${formatDateId(widget.filter.start)} – '
                '${formatDateId(widget.filter.end)} • $_typeLabel',
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
class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.api,
    required this.row,
    required this.filter,
  });
  final AttendanceRecapApi api;
  final RecapRow row;
  final RecapFilter filter;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
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
              AttendanceCountTile(status: 'HADIR', count: row.counts.present),
              AttendanceCountTile(status: 'TERLAMBAT', count: row.counts.late),
              AttendanceCountTile(status: 'IZIN', count: row.counts.permit),
              AttendanceCountTile(status: 'SAKIT', count: row.counts.sick),
              AttendanceCountTile(status: 'ALFA', count: row.counts.absent),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: FutureBuilder<List<HistoryEntry>>(
              future: api.history(row.studentId, filter),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) return Text('${snap.error}');
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Text('Belum ada sesi pada periode ini.');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final how = switch (e.method) {
                      'QR' => 'Pindai QR',
                      'MANUAL' => 'Manual oleh ${e.recordedBy ?? '-'}',
                      _ => 'Belum tercatat',
                    };
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        e.type == 'PAGI'
                            ? Icons.wb_sunny_outlined
                            : Icons.mosque_outlined,
                        color: attendanceTeal,
                      ),
                      title: Text(
                        '${formatYmd(e.date)} • '
                        '${e.type == 'PAGI' ? 'Pagi' : 'Zuhur'}',
                      ),
                      subtitle: Text(
                        '$how • ${formatHhmm(e.time)}'
                        '${e.note == null ? '' : '\nAlasan: ${e.note}'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      isThreeLine: e.note != null,
                      trailing: AttendanceStatusBadge(e.status),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
