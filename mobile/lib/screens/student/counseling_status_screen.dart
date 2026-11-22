import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';

class CounselingStatusScreen extends StatefulWidget {
  const CounselingStatusScreen({super.key, this.api});
  final AuthApi? api;

  @override
  State<CounselingStatusScreen> createState() => _CounselingStatusScreenState();
}

class _CounselingStatusScreenState extends State<CounselingStatusScreen> {
  int _activeTab = 0; // 0: Kasus Aktif, 1: Riwayat Selesai
  bool _loading = true;
  Map<String, dynamic>? _counselingData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      if (widget.api != null) {
        final res = await widget.api!.studentCounseling();
        setState(() => _counselingData = res);
      } else {
        setState(() {
          _counselingData = {
            'active_cases_count': 1,
            'resolved_cases_count': 1,
            'privacy_banner':
                'Privasi Terjamin: Catatan sesi bersifat tertutup & dilindungi kode etik BK.',
            'active_case': {
              'code': 'Berkas #BK-2025',
              'status': 'Pemantauan',
              'counselor': {
                'name': 'Dra. Hj. Ratna Juwita, M.Pd',
                'role': 'Koordinator BK',
              },
              'progress_notes':
                  '“Siswa menunjukkan komitmen adaptasi belajar yang sangat positif. Program pendampingan berkala berjalan terarah.”',
              'progress_phase': {
                'title': 'Tahap 2: Pendampingan & Observasi',
                'step': 2,
                'total_steps': 3,
                'steps': [
                  {'label': 'Konsultasi Awal (24 Feb)', 'done': true},
                  {'label': 'Berjalan', 'done': true},
                  {'label': 'Evaluasi Akhir', 'done': false},
                ],
              },
              'upcoming_session': {
                'type': 'Tatap Muka',
                'date_formatted': 'Kamis, 06 Maret 2025',
                'time': '09:30 WIB',
                'location': 'Ruang BK 02 (Gedung A)',
              },
            },
          };
        });
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCase = _counselingData?['active_case'] as Map<String, dynamic>?;
    final counselor = activeCase?['counselor'] as Map<String, dynamic>?;
    final progress = activeCase?['progress_phase'] as Map<String, dynamic>?;
    final session = activeCase?['upcoming_session'] as Map<String, dynamic>?;

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
          children: const [
            Text(
              'Status Konseling',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
            Text(
              'SIKAP SMAN 12 PADANG',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, color: navy, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: navy, size: 20),
            onPressed: () {},
          ),
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: const CircleAvatar(
              radius: 13,
              backgroundColor: Color(0xFFE0EAF8),
              child: Icon(Icons.person, size: 16, color: navy),
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
                    // Privacy Guarantee Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Privasi Terjamin: Catatan sesi bersifat tertutup & dilindungi kode etik BK.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF0369A1),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Segmented Tabs: Kasus Aktif (1) | Riwayat Selesai (1)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _activeTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _activeTab == 0
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _activeTab == 0
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x10000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0D9488),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Kasus Aktif (${_counselingData?['active_cases_count'] ?? 1})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _activeTab == 0
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: const Color(0xFF0F2942),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _activeTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _activeTab == 1
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _activeTab == 1
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x10000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Riwayat Selesai (${_counselingData?['resolved_cases_count'] ?? 1})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _activeTab == 1
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_activeTab == 0) ...[
                      // Active Case Card
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
                            // Counselor row
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Color(0xFFFEF3C7),
                                  child: Icon(
                                    Icons.support_agent,
                                    color: Color(0xFFD97706),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        counselor?['name'] as String? ??
                                            'Dra. Hj. Ratna Juwita, M.Pd',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F2942),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        '${counselor?['role'] ?? 'Koordinator BK'} • ${activeCase?['code'] ?? 'Berkas #BK-2025'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
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
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF0284C7),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        activeCase?['status'] as String? ??
                                            'Pemantauan',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Notes quote card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: const Border(
                                  left: BorderSide(
                                    color: Color(0xFF0284C7),
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Catatan Kemajuan Siswa',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activeCase?['progress_notes'] as String? ??
                                        '“Siswa menunjukkan komitmen adaptasi belajar yang sangat positif. Program pendampingan berkala berjalan terarah.”',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.45,
                                      color: Color(0xFF475569),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Progress phase
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  progress?['title'] as String? ??
                                      'Tahap 2: Pendampingan & Observasi',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F2942),
                                  ),
                                ),
                                Text(
                                  '${progress?['step'] ?? 2} dari ${progress?['total_steps'] ?? 3}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: const LinearProgressIndicator(
                                value: 0.66,
                                minHeight: 6,
                                backgroundColor: Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0284C7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Stepper Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  '✓ Konsultasi Awal (24 Feb)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF0D9488),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Berjalan',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Evaluasi Akhir',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sesi Mendatang Card
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.event_outlined,
                                      size: 16,
                                      color: Color(0xFF0F2942),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Sesi Mendatang',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F2942),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    session?['type'] as String? ?? 'Tatap Muka',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4338CA),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session?['date_formatted'] as String? ??
                                        'Kamis, 06 Maret 2025',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F2942),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${session?['time'] ?? '09:30 WIB'} • ${session?['location'] ?? 'Ruang BK 02 (Gedung A)'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Action buttons: Chat Guru BK & Ubah Jadwal
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0A2540),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Membuka chat internal dengan Guru BK...',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.chat_outlined,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Chat Guru BK',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFE0F2FE),
                                      foregroundColor: const Color(0xFF0369A1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Pengajuan ubah jadwal sesi konseling dikirim ke Guru BK.',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.calendar_month,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'Ubah Jadwal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Resolved case item
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Berkas #BK-2024 • Selesai',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F2942),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Konsultasi minat bakat dan pemilihan konsentrasi mata pelajaran telah rampung pada 15 Des 2024.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // Help Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.favorite_border,
                                color: Color(0xFF16A34A),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Butuh teman bicara?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF14532D),
                                  ),
                                ),
                                Text(
                                  'Ruang BK selalu terbuka',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF15803D),
                              side: const BorderSide(color: Color(0xFF86EFAC)),
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
                                    'Menghubungi layanan konseling BK SMAN 12 Padang...',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.phone_outlined, size: 14),
                            label: const Text(
                              'Hubungi BK',
                              style: TextStyle(fontSize: 11),
                            ),
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
}
