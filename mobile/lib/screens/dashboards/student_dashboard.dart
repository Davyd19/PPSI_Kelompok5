import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    this.data,
    this.name,
    this.onBadges,
    this.onProfile,
    this.onNotifications,
    this.onHistory,
  });

  final Map<String, dynamic>? data;
  final String? name;
  final VoidCallback? onBadges;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final VoidCallback? onHistory;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  void _showScanQrDialog() {
    String selected = 'Pagi';
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Simulasi Scan QR Presensi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Presensi SMAN 12 Padang tercatat tepat waktu pukul 06.42 WIB.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: ['Pagi', 'Zuhur']
                    .map(
                      (s) => ChoiceChip(
                        label: Text(s),
                        selected: selected == s,
                        onSelected: (_) => update(() => selected = s),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Status: Hadir Tepat Waktu (24 Hari Berturut-turut)',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0D9488),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Presensi $selected berhasil diverifikasi!'),
                    backgroundColor: const Color(0xFF082B50),
                  ),
                );
              },
              child: const Text('Scan Berhasil'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPointsDetail() {
    showDetails(
      context,
      title: 'Poin Apresiasi Siswa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.trending_up, color: Color(0xFF059669), size: 28),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+85 Poin',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      'Predikat: Baik • Semester Ganjil 2026/2027',
                      style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Riwayat Perolehan Poin',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 10),
          _pointItem(
            'Juara 1 OSN Kimia 2025',
            'Prestasi Akademik • Diverifikasi Pembina',
            '+35 Poin',
          ),
          _pointItem(
            'Kehadiran 100% Bulan Oktober',
            'Disiplin Kehadiran Sekolah',
            '+30 Poin',
          ),
          _pointItem(
            'Keaktifan Ekstrakurikuler',
            'Partisipasi Rutin & Tanggung Jawab',
            '+20 Poin',
          ),
        ],
      ),
    );
  }

  static Widget _pointItem(String title, String subtitle, String point) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: navy,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              point,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisciplineDetail() {
    showDetails(
      context,
      title: 'Status Kedisiplinan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF0284C7), size: 28),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '0 Kasus',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                    Text(
                      'Status: Bersih • Tidak ada pelanggaran',
                      style: TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Catatan Pembinaan & BK',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Siswa selalu menaati tata tertib sekolah, tidak pernah terlambat dalam 24 hari terakhir, serta memelihara etika berpakaian dan pergaulan yang baik di SMAN 12 Padang.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  void _showAchievementDetail() {
    showDetails(
      context,
      title: 'Verifikasi Prestasi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Juara 1 OSN Kimia 2025',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tingkat Kota Padang • Bidang Sains & Kimia',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Verifikasi: Disetujui Pembina',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF0D9488),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Reward Poin: +35 Poin Apresiasi',
                  style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                ),
                SizedBox(height: 4),
                Text(
                  'Waktu Persetujuan: 2 jam lalu',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllActivities() {
    showDetails(
      context,
      title: 'Semua Aktivitas Siswa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityCard(
            accentColor: const Color(0xFF34D399),
            icon: Icons.military_tech_outlined,
            iconBgColor: const Color(0xFFEBF3FE),
            iconColor: const Color(0xFF082B50),
            category: 'VERIFIKASI PRESTASI',
            categoryColor: const Color(0xFF0D9488),
            timeAgo: '2 jam lalu',
            title: 'Juara 1 OSN Kimia 2025',
            subtitlePrefix: 'Disetujui Pembina • ',
            highlightText: '+35 Poin',
            highlightColor: const Color(0xFF059669),
            onTap: _showAchievementDetail,
          ),
          const SizedBox(height: 12),
          _ActivityCard(
            accentColor: const Color(0xFF38BDF8),
            icon: Icons.workspace_premium,
            iconBgColor: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            category: 'BADGE DIRAIH',
            categoryColor: const Color(0xFF0284C7),
            timeAgo: 'Kemarin',
            title: 'Badge Disiplin Perak',
            subtitlePrefix: 'Pencapaian kehadiran 100% konsisten •..',
            highlightText: '',
            onTap: () {
              Navigator.pop(context);
              widget.onBadges?.call();
            },
          ),
          const SizedBox(height: 12),
          _ActivityCard(
            accentColor: const Color(0xFFA78BFA),
            icon: Icons.event_available_outlined,
            iconBgColor: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF7C3AED),
            category: 'PRESENSI SEKOLAH',
            categoryColor: const Color(0xFF7C3AED),
            timeAgo: 'Hari ini',
            title: 'Presensi Pagi Tepat Waktu',
            subtitlePrefix: 'Tercatat pukul 06.42 WIB • ',
            highlightText: 'Hadir',
            highlightColor: const Color(0xFF059669),
            onTap: _showScanQrDialog,
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet() {
    showDetails(
      context,
      title: 'Notifikasi Siswa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFD1FAE5),
              child: Icon(Icons.check, color: Color(0xFF059669)),
            ),
            title: const Text(
              'Prestasi Diverifikasi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
            ),
            subtitle: const Text(
              'Juara 1 OSN Kimia 2025 disetujui (+35 Poin)',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Text(
              '2 jam lalu',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ),
          const Divider(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(Icons.workspace_premium, color: Color(0xFF0284C7)),
            ),
            title: const Text(
              'Badge Baru Diraih',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
            ),
            subtitle: const Text(
              'Selamat! Anda meraih Badge Disiplin Perak',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Text(
              'Kemarin',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ),
          const Divider(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEBF3FE),
              child: Icon(Icons.access_time, color: Color(0xFF082B50)),
            ),
            title: const Text(
              'Presensi Berhasil',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: navy,
              ),
            ),
            subtitle: const Text(
              'Hadir tepat waktu hari ini pukul 06.42 WIB',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Text(
              '06.42',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentData = widget.data?['student'] as Map<String, dynamic>?;
    final displayName =
        widget.name != null &&
            widget.name!.isNotEmpty &&
            widget.name != 'Siswa Contoh'
        ? widget.name!
        : (studentData?['name'] as String? ?? 'Muhammad Raihan Al-Farisi');

    final displayClassroomNisn =
        studentData != null && studentData['classroom'] != null
        ? '${studentData['classroom']} • NISN: ${studentData['nisn']}'
        : 'XI MIPA 1 • NISN: 0071298451';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Student Greeting Row
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12082B50),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        backgroundColor: Color(0xFFE2E8F0),
                        child: Icon(
                          Icons.person,
                          size: 28,
                          color: Color(0xFF082B50),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text(
                            'Selamat Pagi, ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text('✨', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF082B50),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayClassroomNisn,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onNotifications ?? _showNotificationsSheet,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEBF3FE),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          color: Color(0xFF082B50),
                          size: 22,
                        ),
                        Positioned(
                          top: 10,
                          right: 11,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Attendance Hero Card (Dark Navy)
            InkWell(
              onTap: _showScanQrDialog,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF132B45),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18082B50),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 15,
                          color: Color(0xFF7EE8C6),
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            '24 Hari Tepat Waktu',
                            style: TextStyle(
                              color: Color(0xFF7EE8C6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF073D35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '06.42 WIB • Hadir',
                            style: TextStyle(
                              color: Color(0xFF6DECB9),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D3754),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum'].map((
                          day,
                        ) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                day,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6DECB9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Color(0xFF0F2942),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Two Metric Cards Side by Side
            Row(
              children: [
                // Poin Apresiasi
                Expanded(
                  child: InkWell(
                    onTap: _showPointsDetail,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDF2F7)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08082B50),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Poin Apresiasi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD1FAE5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.trending_up,
                                    size: 15,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '+85 Poin',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF082B50),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: const [
                              Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: Color(0xFF0D9488),
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Baik',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D9488),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Kedisiplinan
                Expanded(
                  child: InkWell(
                    onTap: _showDisciplineDetail,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDF2F7)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08082B50),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Kedisiplinan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE0F2FE),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.shield_outlined,
                                    size: 15,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '0 Kasus',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF082B50),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Expanded(
                                child: Text(
                                  'Bersih',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section Header: Aktivitas Terbaru
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text(
                          'Aktivitas Terbaru',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF082B50),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D9488),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showAllActivities,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Semua',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: Color(0xFF0284C7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Card 1: Verifikasi Prestasi
            _ActivityCard(
              accentColor: const Color(0xFF34D399),
              icon: Icons.military_tech_outlined,
              iconBgColor: const Color(0xFFEBF3FE),
              iconColor: const Color(0xFF082B50),
              category: 'VERIFIKASI PRESTASI',
              categoryColor: const Color(0xFF0D9488),
              timeAgo: '2 jam lalu',
              title: 'Juara 1 OSN Kimia 2025',
              subtitlePrefix: 'Disetujui Pembina • ',
              highlightText: '+35 Poin',
              highlightColor: const Color(0xFF059669),
              onTap: _showAchievementDetail,
            ),
            const SizedBox(height: 12),

            // Card 2: Badge Diraih
            _ActivityCard(
              accentColor: const Color(0xFF38BDF8),
              icon: Icons.workspace_premium,
              iconBgColor: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              category: 'BADGE DIRAIH',
              categoryColor: const Color(0xFF0284C7),
              timeAgo: 'Kemarin',
              title: 'Badge Disiplin Perak',
              subtitlePrefix: 'Pencapaian kehadiran 100% konsisten •..',
              highlightText: '',
              onTap:
                  widget.onBadges ??
                  () => showDetails(
                    context,
                    title: 'Badge Disiplin Perak',
                    child: const Text(
                      'Pencapaian kehadiran 100% konsisten selama satu bulan penuh tanpa terlambat.',
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.accentColor,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.category,
    required this.categoryColor,
    required this.timeAgo,
    required this.title,
    required this.subtitlePrefix,
    required this.highlightText,
    this.highlightColor,
    required this.onTap,
  });

  final Color accentColor, iconBgColor, iconColor, categoryColor;
  final Color? highlightColor;
  final IconData icon;
  final String category, timeAgo, title, subtitlePrefix, highlightText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06082B50),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accentColor),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(icon, color: iconColor, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: categoryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  timeAgo,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF082B50),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                text: subtitlePrefix,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                                children: [
                                  if (highlightText.isNotEmpty)
                                    TextSpan(
                                      text: highlightText,
                                      style: TextStyle(
                                        color:
                                            highlightColor ??
                                            const Color(0xFF082B50),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
