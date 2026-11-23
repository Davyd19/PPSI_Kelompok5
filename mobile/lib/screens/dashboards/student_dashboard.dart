import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../widgets/shared.dart';
import '../student/achievements_screen.dart';
import '../student/attendance_history_screen.dart';
import '../student/counseling_status_screen.dart';
import '../student/extracurricular_list_screen.dart';
import '../student/notifications_screen.dart';
import '../student/scan_qr_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    this.api,
    this.data,
    this.name,
    this.onBadges,
    this.onProfile,
    this.onNotifications,
    this.onHistory,
  });

  final AuthApi? api;
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
  Map<String, dynamic>? _backendData;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    if (widget.api == null) return;
    try {
      final res = await widget.api!.studentDashboard();
      if (mounted) setState(() => _backendData = res);
    } catch (_) {
      // Keep offline or fixture data
    }
  }

  void _openScanQr() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ScanQrScreen(api: widget.api)))
        .then((_) => _fetchDashboard());
  }

  void _openHistory() {
    if (widget.onHistory != null) {
      widget.onHistory!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttendanceHistoryScreen(api: widget.api),
        ),
      );
    }
  }

  void _openCounseling() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CounselingStatusScreen(api: widget.api),
      ),
    );
  }

  void _openExtracurriculars() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExtracurricularListScreen(api: widget.api),
      ),
    );
  }

  void _openAchievements() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => AchievementsScreen(api: widget.api),
          ),
        )
        .then((_) => _fetchDashboard());
  }

  void _openNotifications() {
    if (widget.onNotifications != null) {
      widget.onNotifications!();
    } else {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => NotificationsScreen(api: widget.api),
            ),
          )
          .then((_) => _fetchDashboard());
    }
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
            onTap: () {
              Navigator.pop(context);
              _openAchievements();
            },
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
            onTap: () {
              Navigator.pop(context);
              _openHistory();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawData = _backendData ?? widget.data;
    final studentData = rawData?['student'] as Map<String, dynamic>?;
    final attSummary = rawData?['attendance_summary'] as Map<String, dynamic>?;
    final metrics = rawData?['metrics'] as Map<String, dynamic>?;

    final displayName =
        studentData?['name'] as String? ??
        (widget.name != null &&
                widget.name!.isNotEmpty &&
                widget.name != 'Siswa Contoh'
            ? widget.name!
            : (studentData?['name'] as String? ?? 'Siswa'));

    final displayClassroomNisn =
        studentData != null && studentData['classroom'] != null
        ? '${studentData['classroom']} • NISN: ${studentData['nisn'] ?? '-'}'
        : (studentData?['nisn'] != null
              ? 'NISN: ${studentData!['nisn']}'
              : 'Siswa SMAN 12');

    final onTimeDays = attSummary?['on_time_days'] ?? 0;
    final todayRecord = attSummary?['today'] as Map<String, dynamic>?;
    final points = metrics?['appreciation_points'] ?? 0;
    final predicate = metrics?['points_predicate'] ?? 'Cukup';
    final cases = metrics?['violation_cases'] ?? 0;
    final disciplineStatus = metrics?['discipline_status'] ?? 'Bersih';
    final unreadNotifs = rawData?['unread_notifications'] ?? 0;
    final recentActivities =
        (rawData?['recent_activities'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: RefreshIndicator(
          onRefresh: _fetchDashboard,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // 1. Student Greeting Row
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
                    onTap: _openNotifications,
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
                          if (unreadNotifs > 0)
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

              // 2. Attendance Hero Card (Dark Navy) -> Taps to Scan QR
              InkWell(
                onTap: _openScanQr,
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
                          Expanded(
                            child: Text(
                              '$onTimeDays Hari Tepat Waktu',
                              style: const TextStyle(
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
                              color: todayRecord != null
                                  ? const Color(0xFF073D35)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              todayRecord != null
                                  ? '${todayRecord['time'] ?? ''} • ${todayRecord['status'] ?? 'Hadir'}'
                                  : 'Belum Presensi',
                              style: TextStyle(
                                color: todayRecord != null
                                    ? const Color(0xFF6DECB9)
                                    : const Color(0xFF94A3B8),
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
                            final dayRecord =
                                ((attSummary?['weekly_grid'] as List?)
                                            ?.cast<Map<String, dynamic>>() ??
                                        [])
                                    .firstWhere(
                                      (it) => it['day'] == day,
                                      orElse: () => <String, dynamic>{},
                                    );
                            final st = dayRecord['status'] as String?;
                            final isPresent = st == 'HADIR';
                            final isLate = st == 'TERLAMBAT';

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
                                  decoration: BoxDecoration(
                                    color: isPresent
                                        ? const Color(0xFF6DECB9)
                                        : isLate
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFF334155),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isPresent
                                          ? Icons.check
                                          : isLate
                                          ? Icons.access_time
                                          : Icons.remove,
                                      size: 16,
                                      color: isPresent
                                          ? const Color(0xFF0F2942)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 14,
                              color: Color(0xFF38BDF8),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Ketuk untuk Pindai Presensi QR Gerbang',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Two Metric Cards Side by Side
              Row(
                children: [
                  // Poin Apresiasi -> opens Achievements
                  Expanded(
                    child: InkWell(
                      onTap: _openAchievements,
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
                            Text(
                              '+$points Poin',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF082B50),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Color(0xFF0D9488),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    predicate,
                                    style: const TextStyle(
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

                  // Kedisiplinan -> opens Counseling
                  Expanded(
                    child: InkWell(
                      onTap: _openCounseling,
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
                            Text(
                              '$cases Kasus',
                              style: const TextStyle(
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
                                Expanded(
                                  child: Text(
                                    disciplineStatus,
                                    style: const TextStyle(
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
              const SizedBox(height: 18),

              // 4. Quick Feature Shortcuts Row
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickAction(
                      icon: Icons.qr_code_scanner,
                      label: 'Presensi',
                      color: const Color(0xFF0D9488),
                      onTap: _openScanQr,
                    ),
                    _buildQuickAction(
                      icon: Icons.history,
                      label: 'Riwayat',
                      color: const Color(0xFF0284C7),
                      onTap: _openHistory,
                    ),
                    _buildQuickAction(
                      icon: Icons.support_agent_outlined,
                      label: 'Konseling',
                      color: const Color(0xFF6366F1),
                      onTap: _openCounseling,
                    ),
                    _buildQuickAction(
                      icon: Icons.sports_kabaddi_outlined,
                      label: 'Ekskul',
                      color: const Color(0xFFF59E0B),
                      onTap: _openExtracurriculars,
                    ),
                    _buildQuickAction(
                      icon: Icons.emoji_events_outlined,
                      label: 'Prestasi',
                      color: const Color(0xFF10B981),
                      onTap: _openAchievements,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 5. Section Header: Aktivitas Terbaru
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

              // Recent Activities (from backend)
              if (recentActivities.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.history_outlined,
                        size: 32,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Belum Ada Aktivitas Terbaru',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F2942),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Aktivitas presensi dan prestasi akan tercatat di sini.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...recentActivities.map((act) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ActivityCard(
                      accentColor: Color(
                        int.parse(
                          (act['accent_color'] as String? ?? '#38BDF8')
                              .replaceFirst('#', '0xFF'),
                        ),
                      ),
                      icon: act['icon'] == 'military_tech'
                          ? Icons.military_tech_outlined
                          : act['icon'] == 'workspace_premium'
                          ? Icons.workspace_premium
                          : Icons.event_available_outlined,
                      iconBgColor: const Color(0xFFEBF3FE),
                      iconColor: const Color(0xFF082B50),
                      category: act['category'] as String? ?? 'AKTIVITAS',
                      categoryColor: Color(
                        int.parse(
                          (act['category_color'] as String? ?? '#0D9488')
                              .replaceFirst('#', '0xFF'),
                        ),
                      ),
                      timeAgo: act['time_ago'] as String? ?? '',
                      title: act['title'] as String? ?? '',
                      subtitlePrefix: act['subtitle_prefix'] as String? ?? '',
                      highlightText: act['highlight_text'] as String? ?? '',
                      highlightColor: act['highlight_color'] != null
                          ? Color(
                              int.parse(
                                (act['highlight_color'] as String).replaceFirst(
                                  '#',
                                  '0xFF',
                                ),
                              ),
                            )
                          : null,
                      onTap: act['type'] == 'achievement'
                          ? _openAchievements
                          : (widget.onBadges ?? () {}),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Icon(icon, color: color, size: 20)),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F2942),
                  ),
                ),
              ),
            ],
          ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(width: 4, height: 76, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(icon, color: iconColor, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: categoryColor,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF082B50),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    subtitlePrefix,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (highlightText.isNotEmpty)
                                  Text(
                                    highlightText,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          highlightColor ??
                                          const Color(0xFF059669),
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
            ],
          ),
        ),
      ),
    );
  }
}
