import '../../widgets/school_ui.dart';
import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({
    super.key,
    this.api,
    this.childId,
    this.onBack,
  });

  final AuthApi? api;
  final int? childId;
  final VoidCallback? onBack;

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen> {
  static const _monthsFull = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  static const _monthsShort = [
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
  static const _daysFull = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  late int _year;
  late int _month;
  String _jenis = 'ALL'; // ALL, PAGI, ZUHUR
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> res;
      if (widget.api != null) {
        res = await widget.api!.parentAttendance(
          childId: widget.childId,
          year: _year,
          month: _month,
          jenis: _jenis == 'ALL' ? null : _jenis,
        );
      } else {
        res = {
          'child': null,
          'month_name': '${_monthsFull[_month - 1]} $_year',
          'stats': {
            'hadir': 0,
            'izin': 0,
            'telat': 0,
            'alfa': 0,
            'rate_percentage': 0,
          },
          'calendar_records': <Map<String, dynamic>>[],
        };
      }
      final records =
          (res['calendar_records'] as List?)?.cast<Map<String, dynamic>>() ??
          [];
      final now = DateTime.now();
      int? defaultDay;
      if (records.isNotEmpty) {
        defaultDay = records.last['day'] as int?;
      } else if (_year == now.year && _month == now.month) {
        defaultDay = now.day;
      }
      if (mounted) {
        setState(() {
          _data = res;
          _selectedDay = defaultDay;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _data = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    int m = _month + delta;
    int y = _year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _year = y;
      _month = m;
      _selectedDay = null;
    });
    _loadData();
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty || parts.first == '-') return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(int y, int m, int d) {
    final dt = DateTime(y, m, d);
    return '${_daysFull[dt.weekday - 1]}, $d ${_monthsShort[m - 1]} $y';
  }

  Color _dotColor(String? status) => switch (status) {
    'HADIR' => const Color(0xFF065F46),
    'IZIN' || 'SAKIT' => const Color(0xFF0F766E),
    'TERLAMBAT' => const Color(0xFF38BDF8),
    'ALFA' => const Color(0xFFDC2626),
    _ => Colors.transparent,
  };

  (Color, Color) _badgeColors(String? status) => switch (status) {
    'HADIR' => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    'TERLAMBAT' => (const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
    'IZIN' || 'SAKIT' => (const Color(0xFFCCFBF1), const Color(0xFF0F766E)),
    'ALFA' => (const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
    _ => (const Color(0xFFF1F5F9), muted),
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canGoNext =
        (_year < now.year) || (_year == now.year && _month < now.month);
    final child = _data?['child'] as Map<String, dynamic>?;
    final stats = _data?['stats'] as Map<String, dynamic>?;
    final records =
        (_data?['calendar_records'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    final recordsByDay = <int, List<Map<String, dynamic>>>{};
    for (final r in records) {
      final d = r['day'] as int?;
      if (d != null) {
        recordsByDay.putIfAbsent(d, () => []).add(r);
      }
    }
    final selectedRecords = _selectedDay != null
        ? (recordsByDay[_selectedDay!] ?? const <Map<String, dynamic>>[])
        : const <Map<String, dynamic>>[];

    final rate = (stats?['rate_percentage'] as num?)?.toDouble() ?? 0;
    final rateLabel = rate == rate.roundToDouble()
        ? '${rate.round()}%'
        : '${rate.toStringAsFixed(1)}%';
    final childName = child?['name'] as String? ?? '-';

    return Scaffold(
      backgroundColor: canvas,
      appBar: widget.onBack != null
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: navy,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text(
                'Kehadiran Anak',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
      body: _loading
          ? const SchoolLoading()
          : (_error != null && _data == null)
          ? LoadErrorView(message: _error!, onRetry: _loadData)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      // Child identity card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE7EDF5)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              child: Text(
                                _initials(childName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    childName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: navy,
                                    ),
                                  ),
                                  Text(
                                    'Kelas ${child?['classroom'] ?? '-'} • NIS ${child?['nis'] ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Baca Saja',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Session type filter (Activity Diagram 3.12: Semua / Pagi / Zuhur)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final entry in const [
                            ('ALL', 'Semua Sesi'),
                            ('PAGI', 'Presensi Pagi'),
                            ('ZUHUR', 'Salat Zuhur'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(entry.$2),
                                selected: _jenis == entry.$1,
                                showCheckmark: false,
                                selectedColor: navy,
                                labelStyle: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: _jenis == entry.$1
                                      ? Colors.white
                                      : navy,
                                ),
                                onSelected: (_) {
                                  if (_jenis == entry.$1) return;
                                  setState(() {
                                    _jenis = entry.$1;
                                    _selectedDay = null;
                                  });
                                  _loadData();
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Month header & stats
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE7EDF5)),
                        ),
                        child: Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${_monthsFull[_month - 1]} $_year',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: navy,
                                      ),
                                    ),
                                    SchoolStatus(
                                      'HADIR',
                                      label: '$rateLabel Hadir',
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'Bulan sebelumnya',
                                      onPressed: () => _changeMonth(-1),
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    IconButton(
                                      tooltip: 'Bulan berikutnya',
                                      onPressed: canGoNext
                                          ? () => _changeMonth(1)
                                          : null,
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _statTile(
                                  'Hadir',
                                  '${stats?['hadir'] ?? 0}',
                                  const Color(0xFF065F46),
                                ),
                                const SizedBox(width: 8),
                                _statTile(
                                  'Izin',
                                  '${stats?['izin'] ?? 0}',
                                  const Color(0xFF0F766E),
                                ),
                                const SizedBox(width: 8),
                                _statTile(
                                  'Telat',
                                  '${stats?['telat'] ?? 0}',
                                  const Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 8),
                                _statTile(
                                  'Alfa',
                                  '${stats?['alfa'] ?? 0}',
                                  const Color(0xFFDC2626),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Calendar
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE7EDF5)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children:
                                  const [
                                        'Sen',
                                        'Sel',
                                        'Rab',
                                        'Kam',
                                        'Jum',
                                        'Sab',
                                        'Min',
                                      ]
                                      .map(
                                        (d) => SizedBox(
                                          width: 34,
                                          child: Text(
                                            d,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: (d == 'Sab' || d == 'Min')
                                                  ? const Color(0xFFDC2626)
                                                  : navy,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 10),
                            _buildCalendar(recordsByDay),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 10),
                            const Wrap(
                              spacing: 14,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                _Legend(Color(0xFF065F46), 'Hadir'),
                                _Legend(Color(0xFF0F766E), 'Izin/Sakit'),
                                _Legend(Color(0xFF38BDF8), 'Terlambat'),
                                _Legend(Color(0xFFDC2626), 'Alfa'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (records.isEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Tidak ada data kehadiran pada periode ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Selected day details
                      if (selectedRecords.isEmpty)
                        _emptyDetailCard(
                          _selectedDay != null
                              ? _formatDate(_year, _month, _selectedDay!)
                              : 'Pilih Tanggal',
                        )
                      else
                        for (final rec in selectedRecords) ...[
                          _detailCard(rec),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCalendar(Map<int, List<Map<String, dynamic>>> recordsByDay) {
    final lead = DateTime(_year, _month, 1).weekday - 1;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final cells = <int?>[
      for (int i = 0; i < lead; i++) null,
      for (int d = 1; d <= daysInMonth; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final rows = <List<int?>>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, i + 7));
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (colIdx) {
              final dayNum = row[colIdx];
              if (dayNum == null) return const SizedBox(width: 34, height: 36);
              final dayRecs = recordsByDay[dayNum];
              final dot = dayRecs != null && dayRecs.isNotEmpty
                  ? _dotColor(dayRecs.first['status'] as String?)
                  : Colors.transparent;
              final isSelected = dayNum == _selectedDay;
              final isWeekend = colIdx >= 5;

              return InkWell(
                onTap: () => setState(() => _selectedDay = dayNum),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 34,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? navy : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isWeekend ? const Color(0xFFDC2626) : navy),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected && dot != Colors.transparent
                              ? const Color(0xFF5EEAD4)
                              : dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      }).toList(),
    );
  }

  Widget _detailCard(Map<String, dynamic> rec) {
    final (bg, fg) = _badgeColors(rec['status'] as String?);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec['date_formatted'] as String? ?? '-',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    Text(
                      rec['jenis_label'] as String? ?? 'Presensi Sekolah',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  rec['status_label'] as String? ?? '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _timeBox(
                  'Jam Masuk',
                  rec['check_in_time'] as String? ?? '-',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _timeBox(
                  'Jam Pulang',
                  rec['check_out_time'] as String? ?? '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catatan Presensi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rec['keterangan'] as String? ??
                      rec['verification_method'] as String? ??
                      '-',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyDetailCard(String dateLabel) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE7EDF5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Tidak Ada Data',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Tidak ada data kehadiran pada tanggal ini.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    ),
  );

  Widget _timeBox(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: canvas,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: muted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
      ],
    ),
  );

  Widget _statTile(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: muted)),
    ],
  );
}
