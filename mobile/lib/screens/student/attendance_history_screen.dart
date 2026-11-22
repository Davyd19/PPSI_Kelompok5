import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key, this.api});
  final AuthApi? api;

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  bool _loading = true;
  Map<String, dynamic>? _historyData;
  int _selectedDay = 24;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      if (widget.api != null) {
        final res = await widget.api!.studentAttendanceHistory();
        setState(() => _historyData = res);
      } else {
        setState(() {
          _historyData = {
            'student': {
              'name': 'Muhammad Raihan Al-Farisi',
              'nisn': '0064928172',
              'classroom': 'XI MIPA 1',
            },
            'academic_year': 'Semester Genap T.A. 2023/2024',
            'month_name': 'Februari 2025',
            'stats': {
              'hadir': 20,
              'telat': 1,
              'izin': 1,
              'alfa': 0,
              'rate_percentage': 95.5,
            },
            'selected_detail': {
              'date_formatted': 'Senin, 24 Feb 2025',
              'status_label': 'Hadir Tepat Waktu',
              'check_in_time': '06:43 WIB',
              'check_out_time': '15:30 WIB',
              'verification_method': 'Terverifikasi via QR Gerbang',
            },
          };
        });
      }
    } catch (_) {
      // Fallback to default mock data if network fails
      setState(() {
        _historyData = {
          'student': {
            'name': 'Muhammad Raihan Al-Farisi',
            'nisn': '0064928172',
            'classroom': 'XI MIPA 1',
          },
          'academic_year': 'Semester Genap T.A. 2023/2024',
          'month_name': 'Februari 2025',
          'stats': {
            'hadir': 20,
            'telat': 1,
            'izin': 1,
            'alfa': 0,
            'rate_percentage': 95.5,
          },
          'selected_detail': {
            'date_formatted': 'Senin, 24 Feb 2025',
            'status_label': 'Hadir Tepat Waktu',
            'check_in_time': '06:43 WIB',
            'check_out_time': '15:30 WIB',
            'verification_method': 'Terverifikasi via QR Gerbang',
          },
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _historyData?['stats'] as Map<String, dynamic>?;
    final student = _historyData?['student'] as Map<String, dynamic>?;
    final detail = _historyData?['selected_detail'] as Map<String, dynamic>?;

    final studentName =
        student?['name'] as String? ?? 'Muhammad Raihan Al-Farisi';
    final studentClassNisn =
        'NISN: ${student?['nisn'] ?? '0064928172'} • ${student?['classroom'] ?? 'XI MIPA 1'}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
            Text(
              _historyData?['academic_year'] as String? ??
                  'Semester Genap T.A. 2023/2024',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFE0EAF8),
              child: Icon(Icons.person, size: 18, color: navy),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
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
                            child: const Center(
                              child: Text(
                                'MR',
                                style: TextStyle(
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
                                        borderRadius: BorderRadius.circular(10),
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
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            size: 20,
                            color: Color(0xFF0F2942),
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
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 16,
                                color: Color(0xFF0F2942),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Februari 2025',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F2942),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF0F2942),
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
                          value: '${stats?['hadir'] ?? 20}',
                          dotColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        _buildStatBox(
                          label: 'Telat',
                          value: '${stats?['telat'] ?? 1}',
                          dotColor: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 6),
                        _buildStatBox(
                          label: 'Izin',
                          value: '${stats?['izin'] ?? 1}',
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
                                  '${stats?['rate_percentage'] ?? 95.5}%',
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
                          // Calendar Grid
                          _buildCalendarDays(),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),
                          // Legend Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: const [
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
                              Text(
                                detail?['date_formatted'] as String? ??
                                    'Senin, 24 Feb 2025',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F2942),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  detail?['status_label'] as String? ??
                                      'Hadir Tepat Waktu',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
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
                                            detail?['check_in_time']
                                                    as String? ??
                                                '06:43 WIB',
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
                                            detail?['check_out_time']
                                                    as String? ??
                                                '15:30 WIB',
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

                          // Verification and Download button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    color: Color(0xFF10B981),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    detail?['verification_method'] as String? ??
                                        'Terverifikasi via QR Gerbang',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Mengunduh rekap presensi PDF...',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.download, size: 14),
                                label: const Text(
                                  'Unduh Rekap',
                                  style: TextStyle(fontSize: 11),
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

  Widget _buildCalendarDays() {
    // Generate dates matching Screenshot 5
    // Row 1: 27 28 29 30 31 1 2
    // Row 2: 3 4 5 6 7 8 9
    // Row 3: 10 11 12 13 14 15 16
    // Row 4: 17 18 19 20 21 22 23
    // Row 5: 24 25 26 27 28 1 2

    final rows = [
      [
        (27, false, null),
        (28, false, null),
        (29, false, null),
        (30, false, null),
        (31, false, null),
        (1, true, null),
        (2, true, null),
      ],
      [
        (3, true, const Color(0xFF10B981)),
        (4, true, const Color(0xFF10B981)),
        (5, true, const Color(0xFF10B981)),
        (6, true, const Color(0xFF10B981)),
        (7, true, const Color(0xFF10B981)),
        (8, true, null),
        (9, true, null),
      ],
      [
        (10, true, const Color(0xFF10B981)),
        (11, true, const Color(0xFF10B981)),
        (12, true, const Color(0xFF38BDF8)),
        (13, true, const Color(0xFF10B981)),
        (14, true, const Color(0xFF10B981)),
        (15, true, null),
        (16, true, null),
      ],
      [
        (17, true, const Color(0xFF10B981)),
        (18, true, const Color(0xFF1E3A8A)),
        (19, true, const Color(0xFF10B981)),
        (20, true, const Color(0xFF10B981)),
        (21, true, const Color(0xFF10B981)),
        (22, true, null),
        (23, true, null),
      ],
      [
        (24, true, const Color(0xFF10B981)),
        (25, true, const Color(0xFF10B981)),
        (26, true, const Color(0xFF10B981)),
        (27, true, const Color(0xFF10B981)),
        (28, true, const Color(0xFF10B981)),
        (1, false, null),
        (2, false, null),
      ],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: row.map((cell) {
              final dayNum = cell.$1;
              final isCurrentMonth = cell.$2;
              final dotColor = cell.$3;
              final isSelected = isCurrentMonth && dayNum == _selectedDay;

              return InkWell(
                onTap: isCurrentMonth
                    ? () => setState(() => _selectedDay = dayNum)
                    : null,
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
                                  : (isCurrentMonth
                                        ? FontWeight.w600
                                        : FontWeight.w400),
                              color: isSelected
                                  ? Colors.white
                                  : (isCurrentMonth
                                        ? const Color(0xFF0F2942)
                                        : const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dotColor ?? Colors.transparent,
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
