import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key, this.api, this.onBack});
  final AuthApi? api;
  final VoidCallback? onBack;

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  static const _idMonthsFull = [
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

  static const _idMonthsShort = [
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

  static const _idDays = [
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
  Map<String, dynamic>? _historyData;
  late int _year;
  late int _month;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> res;
      if (widget.api != null) {
        res = await widget.api!.studentAttendanceHistory(
          year: _year,
          month: _month,
        );
      } else {
        res = {
          'student': null,
          'academic_year': '',
          'month_name': '${_idMonthsFull[_month - 1]} $_year',
          'stats': {
            'hadir': 0,
            'telat': 0,
            'izin': 0,
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
          _historyData = res;
          _selectedDay = defaultDay;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _historyData = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    int newMonth = _month + delta;
    int newYear = _year;
    if (newMonth < 1) {
      newMonth = 12;
      newYear--;
    } else if (newMonth > 12) {
      newMonth = 1;
      newYear++;
    }
    setState(() {
      _year = newYear;
      _month = newMonth;
      _selectedDay = null;
    });
    _loadHistory();
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

  String _formatLocalDate(int year, int month, int day) {
    final dt = DateTime(year, month, day);
    return '${_idDays[dt.weekday - 1]}, $day ${_idMonthsShort[month - 1]} $year';
  }

  Color _dotColorForStatus(String? status) => switch (status) {
    'HADIR' => const Color(0xFF10B981),
    'TERLAMBAT' => const Color(0xFF38BDF8),
    'IZIN' || 'SAKIT' => const Color(0xFF1E3A8A),
    'ALFA' => const Color(0xFFEF4444),
    _ => Colors.transparent,
  };

  (Color, Color) _badgeColorsForStatus(String? status) => switch (status) {
    'HADIR' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
    'TERLAMBAT' => (const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
    'IZIN' || 'SAKIT' => (const Color(0xFFE0E7FF), const Color(0xFF1E3A8A)),
    'ALFA' => (const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
    _ => (const Color(0xFFF1F5F9), const Color(0xFF64748B)),
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canGoNext =
        (_year < now.year) || (_year == now.year && _month < now.month);
    final stats = _historyData?['stats'] as Map<String, dynamic>?;
    final student = _historyData?['student'] as Map<String, dynamic>?;
    final academicYear = (_historyData?['academic_year'] as String? ?? '')
        .trim();

    final studentName = student?['name'] as String? ?? '-';
    final studentClassNisn =
        'NISN: ${student?['nisn'] ?? '-'} • ${student?['classroom'] ?? '-'}';

    final records =
        (_historyData?['calendar_records'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final recordByDay = <int, Map<String, dynamic>>{};
    for (final rec in records) {
      final d = rec['day'] as int?;
      if (d != null) recordByDay[d] = rec;
    }

    final selectedRecord = _selectedDay != null
        ? recordByDay[_selectedDay!]
        : null;
    final selectedStatus = selectedRecord?['status'] as String?;
    final (badgeBg, badgeFg) = _badgeColorsForStatus(selectedStatus);
    final dateTitle =
        selectedRecord?['date_formatted'] as String? ??
        (_selectedDay != null
            ? _formatLocalDate(_year, _month, _selectedDay!)
            : 'Pilih Tanggal');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.onBack != null
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: navy,
              elevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riwayat Presensi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  if (academicYear.isNotEmpty)
                    Text(
                      academicYear,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                ],
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _historyData == null)
          ? LoadErrorView(message: _error!, onRetry: _loadHistory)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // Student Profile Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x08082B50),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFF132B45),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _initials(studentName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          studentName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F2942),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          'SMAN 12',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1D4ED8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    studentClassNisn,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Month Selector Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => _changeMonth(-1),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Icon(
                                Icons.chevron_left,
                                size: 20,
                                color: Color(0xFF0F2942),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 16,
                                  color: Color(0xFF0F2942),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_idMonthsFull[_month - 1]} $_year',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F2942),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: canGoNext ? () => _changeMonth(1) : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: canGoNext
                                    ? const Color(0xFF0F2942)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Stats Row: Hadir, Telat, Izin, Alfa, Laju %
                      Row(
                        children: [
                          _buildStatBox(
                            label: 'Hadir',
                            value: '${stats?['hadir'] ?? 0}',
                            dotColor: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          _buildStatBox(
                            label: 'Telat',
                            value: '${stats?['telat'] ?? 0}',
                            dotColor: const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          _buildStatBox(
                            label: 'Izin',
                            value: '${stats?['izin'] ?? 0}',
                            dotColor: const Color(0xFF1E3A8A),
                          ),
                          const SizedBox(width: 6),
                          _buildStatBox(
                            label: 'Alfa',
                            value: '${stats?['alfa'] ?? 0}',
                            dotColor: const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF064E3B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Laju',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF6EE7B7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${stats?['rate_percentage'] ?? 0}%',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Calendar Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06082B50),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Days Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children:
                                  [
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
                                          width: 32,
                                          child: Text(
                                            d,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: d == 'Min'
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF0D9488),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 12),
                            _buildCalendarDays(recordByDay),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 12),
                            // Legend Row
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _LegendItem(
                                  color: Color(0xFF10B981),
                                  label: 'Hadir',
                                ),
                                _LegendItem(
                                  color: Color(0xFF38BDF8),
                                  label: 'Terlambat',
                                ),
                                _LegendItem(
                                  color: Color(0xFF1E3A8A),
                                  label: 'Izin/Sakit',
                                ),
                                _LegendItem(
                                  color: Color(0xFFEF4444),
                                  label: 'Alfa',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (records.isEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Belum ada data presensi pada bulan ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Rincian Kehadiran Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06082B50),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RINCIAN KEHADIRAN',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    dateTitle,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F2942),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    selectedRecord?['status_label']
                                            as String? ??
                                        'Tidak Ada Data',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: badgeFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 2 boxes: Masuk & Pulang
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.login,
                                          size: 18,
                                          color: Color(0xFF0F2942),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Masuk',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            Text(
                                              selectedRecord?['check_in_time']
                                                      as String? ??
                                                  '-',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F2942),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.logout,
                                          size: 18,
                                          color: Color(0xFF0F2942),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Pulang',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            Text(
                                              selectedRecord?['check_out_time']
                                                      as String? ??
                                                  '-',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F2942),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Verification method row
                            Row(
                              children: [
                                Icon(
                                  selectedRecord != null
                                      ? Icons.verified
                                      : Icons.info_outline,
                                  color: selectedRecord != null
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    selectedRecord?['verification_method']
                                            as String? ??
                                        'Tidak ada data presensi pada tanggal ini',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required Color dotColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F2942),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDays(Map<int, Map<String, dynamic>> recordByDay) {
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
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: row.map((dayNum) {
              if (dayNum == null) {
                return const SizedBox(width: 32, height: 34);
              }
              final rec = recordByDay[dayNum];
              final dotColor = _dotColorForStatus(rec?['status'] as String?);
              final isSelected = dayNum == _selectedDay;

              return InkWell(
                onTap: () => setState(() => _selectedDay = dayNum),
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF132B45)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F2942),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
