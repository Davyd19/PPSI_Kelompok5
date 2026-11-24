import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class ParentExtracurricularScreen extends StatefulWidget {
  const ParentExtracurricularScreen({super.key, this.api, this.childId});

  final AuthApi? api;
  final int? childId;

  @override
  State<ParentExtracurricularScreen> createState() =>
      _ParentExtracurricularScreenState();
}

class _ParentExtracurricularScreenState
    extends State<ParentExtracurricularScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.api != null) {
        final res = await widget.api!.parentExtracurriculars(
          childId: widget.childId,
        );
        if (mounted) setState(() => _data = res);
      } else {
        if (mounted) {
          setState(() {
            _data = {
              'child': null,
              'summary': {
                'enrolled_count': 0,
                'average_attendance_rate': 0,
                'academic_year': '-',
                'semester_name': '',
              },
              'items': <Map<String, dynamic>>[],
            };
          });
        }
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

  // Activity Diagram 3.15: informasi kegiatan + riwayat sesi pertemuan + detail status tiap sesi
  void _showActivityDetail(Map<String, dynamic> item) {
    final sessions =
        (item['sessions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    showDetails(
      context,
      title: item['name'] as String? ?? 'Detail Ekstrakurikuler',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Status Keanggotaan', item['status_keanggotaan'] as String? ?? '-'),
          _kv('Pembina', item['coach'] as String? ?? 'Belum ditentukan'),
          _kv('Jadwal', item['schedule'] as String? ?? 'Belum dijadwalkan'),
          _kv('Lokasi', item['location'] as String? ?? '-'),
          _kv(
            'Kehadiran',
            '${item['attended_count'] ?? 0} / ${item['total_sessions'] ?? 0} pertemuan (${item['attendance_rate'] ?? 0}%)',
          ),
          if (item['description'] != null) ...[
            const SizedBox(height: 6),
            Text(
              item['description'] as String,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Riwayat Sesi Pertemuan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            const Text(
              'Belum ada riwayat sesi pertemuan.',
              style: TextStyle(fontSize: 12, color: muted),
            )
          else
            for (final s in sessions) _sessionTile(s),
        ],
      ),
    );
  }

  Widget _sessionTile(Map<String, dynamic> s) {
    final recorded = s['recorded'] == true;
    final status = recorded
        ? (s['status_kehadiran'] as String? ?? '-')
        : 'Belum Diisi';
    final statusBg = !recorded
        ? const Color(0xFFF1F5F9)
        : status == 'HADIR'
        ? const Color(0xFFDCFCE7)
        : status == 'ALFA'
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFE0F2FE);
    final statusFg = !recorded
        ? muted
        : status == 'HADIR'
        ? const Color(0xFF15803D)
        : status == 'ALFA'
        ? const Color(0xFFDC2626)
        : const Color(0xFF0369A1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['date_formatted'] as String? ??
                      s['tanggal'] as String? ??
                      '-',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
                if (s['agenda'] != null)
                  Text(
                    s['agenda'] as String,
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                if (s['keterangan'] != null)
                  Text(
                    'Catatan: ${s['keterangan']}',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: statusFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: navy,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final child = _data?['child'] as Map<String, dynamic>?;
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final items =
        (_data?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final childName = child?['name'] as String? ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kegiatan Ekstrakurikuler Anak',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                      // Child summary card
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        childName,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: navy,
                                        ),
                                      ),
                                      Text(
                                        '${child?['classroom'] ?? '-'} • NISN ${child?['nisn'] ?? '-'}',
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
                                    'Pantau',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _metricTile(
                                    Icons.verified_user_outlined,
                                    'Terdaftar',
                                    '${summary?['enrolled_count'] ?? 0} Ekskul',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _metricTile(
                                    Icons.pie_chart_outline,
                                    'Rata-rata',
                                    '${summary?['average_attendance_rate'] ?? 0}%',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ekstrakurikuler Diikuti',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: navy,
                                ),
                              ),
                              Text(
                                'Tahun Ajaran ${summary?['academic_year'] ?? '-'} • SMAN 12 Padang',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                          if ((summary?['semester_name'] as String? ?? '')
                              .isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'SMT ${summary!['semester_name']}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (items.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 36,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE7EDF5)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                size: 42,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Anak belum terdaftar pada kegiatan ekstrakurikuler',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final item in items) _ekskulCard(item),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: muted),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Presensi dicatat otomatis oleh Pembina melalui sistem SIKAP. Ketuk kartu kegiatan untuk melihat riwayat pertemuan.',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
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

  Widget _metricTile(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0F766E)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: muted)),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _ekskulCard(Map<String, dynamic> item) {
    final rate = (item['attendance_rate'] as num?)?.toInt() ?? 0;
    return InkWell(
      onTap: () => _showActivityDetail(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.groups_outlined,
                    color: navy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] as String? ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: navy,
                        ),
                      ),
                      Text(
                        item['coach'] as String? ?? 'Pembina belum ditentukan',
                        style: const TextStyle(fontSize: 11.5, color: muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$rate%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (item['schedule'] != null)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 13, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    item['schedule'] as String,
                    style: const TextStyle(fontSize: 11.5, color: muted),
                  ),
                ],
              ),
            if (item['location'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['location'] as String,
                      style: const TextStyle(fontSize: 11.5, color: muted),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kehadiran (${item['attended_count'] ?? 0} / ${item['total_sessions'] ?? 0} pertemuan)',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                Text(
                  item['activity_label'] as String? ?? '-',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: const Color(0xFFE0F2FE),
              color: const Color(0xFF10B981),
            ),
          ],
        ),
      ),
    );
  }
}
